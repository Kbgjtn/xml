const std = @import("std");

pub const Token = struct {
    start: u32,
    tag: Tag,
    len: u16,

    pub const default: Token = .{
        .tag = .character,
        .len = 0,
        .start = 0,
    };

    pub const eof: Token = .{
        .tag = .eof,
        .len = 0,
        .start = 0,
    };

    pub fn init(tag: Tag, start: u32, len: u16) Token {
        return .{
            .tag = tag,
            .len = len,
            .start = start,
        };
    }

    pub const PredefinedGeneralEntities: std.StaticStringMap(void) =
        .initComptime(&.{
            .{"amp"},
            .{"lt"},
            .{"gt"},
            .{"apos"},
            .{"quot"},
        });

    pub const Tag = enum {
        character,
        invalid,
        start_tag,
        start_tag_self_closing,
        end_tag,
        comment,
        cdata,
        element_declaration,
        attribute_list_declaration,
        pi,
        doctype,
        xml_declaration,
        eof,
        unknown,
    };

    pub const PredefinedGeneralEntities: std.StaticStringMap(void) =
        .initComptime(&.{
            .{"amp"},
            .{"lt"},
            .{"gt"},
            .{"apos"},
            .{"quot"},
        });

    /// Create a Token instance with every field set based on
    /// the given parameters.
    pub fn init(tag: Tag, start: u32, len: u16) Token {
        return .{
            .tag = tag,
            .len = len,
            .start = start,
        };
    }

    pub fn value(self: *const Token, src: []const u8) []const u8 {
        return src[self.start .. self.start + self.len];
    }

    pub fn isWhiteSpace(self: *const Token, src: []const u8) bool {
        if (self.len == 0) return false;
        const content = src[self.start .. self.start + self.len];
        for (content) |c| if (!std.ascii.isWhitespace(c)) return false;
        return true;
    }

    pub fn format(token: *const Token, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("{t} | {};{}", .{
            token.tag,
            token.start,
            token.start + token.len,
        });
    }
};

/// Represents a stored index and length of a value.
/// Case when scanning `processing instruction` need to
/// store the PIData somewhere.
pub const Span = struct {
    start: u32,
    len: u16,

    /// Default empty `Span`.
    /// Every field is initialized to zero.
    pub const default: Span = .{ .start = 0, .len = 0 };

    pub fn init(start: u32, len: u16) Span {
        return .{ .start = start, .len = len };
    }

    pub fn value(self: *const Span, buffer: []const u8) []const u8 {
        return buffer[self.start .. self.start + self.len];
    }

    pub fn format(self: *const Span, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("{};{}", .{ self.start, self.len });
    }
};

pub const Identifier = struct {
    id_start: u32,
    id_len: u16,

    system_start: u32,
    system_len: u16,

    internal_subset_start: u32,
    internal_subset_len: u32,

    public_start: ?u32,
    public_len: ?u16,

    /// Default empty `Identifier`.
    /// Every field is initialized to zero.
    pub const default: Identifier = .{
        .id_len = 0,
        .id_start = 0,
        .system_len = 0,
        .system_start = 0,
        .public_len = 0,
        .public_start = 0,
        .internal_subset_len = 0,
        .internal_subset_start = 0,
    };

    pub fn internalSubset(self: *const Identifier, src: []const u8) []const u8 {
        return src[self.internal_subset_start .. self.internal_subset_start + self.internal_subset_len];
    }

    pub fn systemId(self: *const Identifier, src: []const u8) []const u8 {
        return src[self.system_start .. self.system_start + self.system_len];
    }

    pub fn publicId(self: *const Identifier, src: []const u8) ?[]const u8 {
        const start = self.public_start orelse return null;
        const len = self.public_len orelse return null;
        return src[start .. start + len];
    }

    pub fn print(self: *const Identifier, buffer: []const u8) void {
        std.debug.print("Identifier\n", .{});
        std.debug.print("--------------------\n", .{});
        std.debug.print("system: \"{s}\"\n", .{self.systemId(buffer)});
        if (self.publicId(buffer)) |public_id| {
            std.debug.print("public: \"{s}\"\n", .{public_id});
        }

        return src[self.public_start.? .. self.public_start.? + self.public_len.?];
    }
};

pub const Attribute = struct {
    name_start: u32,
    name_len: u16,
    value_start: u32,
    value_len: u16,

    pub const empty: Attribute = .{
        .name_start = 0,
        .name_len = 0,
        .value_start = 0,
        .value_len = 0,
    };

    pub fn name(self: *const Attribute, src: []const u8) []const u8 {
        return src[self.name_start .. self.name_start + self.name_len];
    }

    pub fn value(self: *const Attribute, src: []const u8) []const u8 {
        return src[self.value_start .. self.value_start + self.value_len];
    }

    pub fn print(self: *const Attribute, source: []const u8) void {
        std.debug.print("Attribute {s} = \"{s}\"\n", .{ self.name(source), self.value(source) });
    }
};

const State = enum {
    state_data,
    state_character_reference,
    state_numeric_reference,
    state_hex_reference,
    state_decimal_reference,
    state_entity_reference,
    state_parameter_entity_reference,

    state_tag_open,
    state_end_tag_open,
    state_tag_name,
    state_self_closing_start_tag,
    state_before_attribute_name,
    state_attribute_name,
    state_after_attribute_name,
    state_before_attribute_value,
    state_attribute_value_double_quoted,
    state_attribute_value_single_quoted,
    state_after_attribute_value,

    state_markup_declaration_open,
    state_comment_start,
    state_comment_start_dash,
    state_comment,
    state_comment_end_dash,
    state_comment_end,
    state_comment_end_bang,

    state_doctype,
    state_before_doctype_name,
    state_doctype_name,
    state_after_doctype_name,
    state_after_doctype_public_keyword,
    state_before_doctype_public_identifier,
    state_doctype_public_identifier_double_quoted,
    state_doctype_public_identifier_single_quoted,
    state_after_doctype_public_identifier,
    state_between_doctype_public_and_system_identifiers,
    state_after_doctype_system_keyword,

    state_before_doctype_system_identifier,
    state_doctype_system_identifier_double_quoted,
    state_doctype_system_identifier_single_quoted,
    state_after_doctype_system_identifier,

    state_doctype_internal_subset,
    state_doctype_internal_subset_string_double_quoted,
    state_doctype_internal_subset_string_single_quoted,
    state_doctype_internal_subset_comment,

    state_bogus_doctype,

    state_cdata_section,

    state_pi_target,
    state_before_pi_data,
    state_pi_data,
    state_pi_close,

    // covers both XMLDecl and TextDecl parsing
    state_xml_declaration,

    state_element_type_declaration_start,
    state_before_element_type_declaration_name,
    state_element_type_declaration_name,
    state_after_element_type_declaration_name,
    state_element_type_before_declaration_content_spec,
    state_element_type_declaration_content_spec_literal,
    state_element_type_declaration_content_spec_grouped,
    state_element_type_declaration_content_spec_grouped_quantifier,

    // ATTLIST
    state_attribute_list_declaration_start,
    state_before_attribute_declaration_name,
    state_attribute_list_declaration_name,
    state_after_attribute_list_declaration_name,

    // ATTDEF_NAME
    state_before_attribute_definition_name,
    state_attribute_definition_name,
    state_after_attribute_definition_name,

    // ATTDEF_TYPE
    state_before_attribute_definition_value_type,
    state_attribute_definition_value_type_reserved,
    state_attribute_definition_value_type_enumerated,
    state_after_attribute_definition_value_type,

    // ATTDEF_DECLARATIOIN
    state_before_attribute_definition_default_decl,
    state_attribute_definition_default_decl,
    state_attribute_definition_default_value_fixed,
    state_after_attribute_definition_default_decl,
};

// TODO
// - [Error Handling] we need a mechanisme to reports
//   an error, to inform the parser (high layer) to decide the action next.
pub const Tokenizer = struct {
    index: u32,
    state: State,

    /// buffer must outlive Tokenizer
    buffer: [:0]const u8,

    // NOTE
    // just to aware of, the inline buffer is
    // not scallable in the long run.

    /// Tokenizer owns, caller borrowed a view of the key value spans
    /// will resets when the `next()` is called.
    attribute_elements: [16]Attribute,
    attribute_elements_count: usize,

    /// Tokenizer owns, caller borrowed a view of the attribute definitions
    /// will resets when the `next()` is called.
    attribute_defs: [16]AttributeDef,
    attribute_defs_count: usize,

    span: ?Span,
    identifier: ?Identifier,

    pub fn init(buffer: [:0]const u8) Tokenizer {
        return .{
            .index = 0,
            .span = null,
            .buffer = buffer,
            .identifier = null,
            .state = .state_data,
            .attribute_defs_count = 0,
            .attribute_elements_count = 0,
            .attribute_elements = [_]Attribute{Attribute.empty} ** 16,
            .attribute_defs = [_]AttributeDef{AttributeDef.empty} ** 16,
        };
    }

    /// Returns a view of the attributes of the current token.
    /// The returned slice becomes invalid after the next `next()` call.
    pub fn attributes(self: *Tokenizer) []const Attribute {
        return self.attribute_elements[0..self.attribute_elements_count];
    }

    pub fn doctypeIdentifier(self: *const Tokenizer) ?Identifier {
        return self.identifier;
    }

    pub fn processInstruction(self: *Tokenizer) ?[]const u8 {
        if (self.span) |v| {
            return self.buffer[v.start .. v.start + v.len];
        }
        return null;
    }

    pub fn contentSpec(self: *Tokenizer) ?[]const u8 {
        if (self.span) |span| {
            return self.buffer[span.start .. span.start + span.len];
        }
        return null;
    }

    pub fn attributeDefinitions(self: *Tokenizer) []const AttributeDef {
        if (self.attribute_defs_count > 0) {
            return self.attribute_defs[0..self.attribute_defs_count];
        }
        return &.{};
    }

    pub fn next(self: *Tokenizer) Token {
        self.span = null;
        self.identifier = null;
        self.kv_count = 0;

        const start_pos = self.index;
        var token: Token = .init(self.index, 0);
        var attribute: Attribute = .empty;

        var mode: enum { read, internal_subset } = .read;

        defer {
            if (token.tag == .doctype) {
                if (self.identifier) |id| {
                    std.debug.print("identifier: {any}\n", .{id});
                    std.debug.print("identifier.system: \"{s}\"\n", .{self.buffer[id.system_start .. id.system_start + id.system_len]});
                    std.debug.print("identifier.public: \"{s}\"\n", .{self.buffer[id.public_start.? .. id.public_start.? + id.public_len.?]});
                    std.debug.print("identifier.internal_subset: \"{s}\"\n", .{self.buffer[id.internal_subset_start .. id.internal_subset_start + id.internal_subset_len]});
                }
                if (self.span) |s| {
                    std.debug.print("span: {any}\n", .{s});
                    std.debug.print("span.value: \"{s}\"\n", .{self.buffer[s.start .. s.start + s.len]});
                }
            }
            if (token.tag == .element_declaration) {
                if (self.span) |s| {
                    std.debug.print("span: {any}\n", .{s});
                    std.debug.print("span.value: \"{s}\"\n", .{self.buffer[s.start .. s.start + s.len]});
                }
            }
        }

        s: switch (self.state) {
            // NOTE latest
            .state_data => {
                if (self.index >= self.buffer.len) {
                    if (token.len > 0) break :s;

                    token.len = 0;
                    token.tag = .eof;
                    token.start = self.index;
                    break :s;
                }

                switch (self.buffer[self.index]) {
                    '<' => {
                        if (token.len > 0) break :s;

                        self.index += 1;
                        self.state = .state_tag_open;
                        continue :s .state_tag_open;
                    },

                    '&' => {
                        token.len += 1;
                        self.index += 1;
                        continue :s .state_character_reference;
                    },

                    else => {
                        token.len += 1;
                        self.index += 1;
                        continue :s .state_data;
                    },
                }
            },

            .state_character_reference => switch (self.buffer[self.index]) {
                '#' => {
                    self.index += 1;
                    continue :s .state_numeric_reference;
                },

                'A'...'Z',
                'a'...'z',
                => {
                    // token.tag = .entity_reference;
                    // token.start = self.index;
                    // self.state = .state_entity_reference;
                    continue :s .state_entity_reference;
                },

                else => {
                    token.tag = .character;
                    token.start = start_pos;
                    token.len = 1;

                    self.state = .state_data;
                    self.index = start_pos + 1;
                    break :s;
                },
            },

            .state_numeric_reference => switch (self.buffer[self.index]) {
                'x', 'X' => {
                    token.len += 1;
                    self.index += 1;
                    // self.state = .state_hex_reference;
                    continue :s .state_hex_reference;
                },

                '0'...'9' => {
                    // self.state = .state_decimal_reference;
                    continue :s .state_decimal_reference;
                },

                ';' => {
                    token.len += 1;
                    // self.index += 1;
                    // self.state = .state_data;
                    continue :s self.state;
                },

                else => {
                    token.tag = .character;
                    token.start = start_pos;
                    token.len = 1;

                    self.state = .state_data;
                    self.index = start_pos + 1;
                    break :s;
                },
            },

            .state_decimal_reference => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    token.len += 1;
                    self.index += 1;
                    continue :s .state_decimal_reference;
                },

                else => {
                    continue :s .state_numeric_reference;
                },
            },

            .state_hex_reference => switch (self.buffer[self.index]) {
                '0'...'9',
                'A'...'F',
                'a'...'f',
                => {
                    token.len += 1;
                    self.index += 1;
                    continue :s .state_hex_reference;
                },

                else => {
                    continue :s .state_numeric_reference;
                },
            },

            .state_entity_reference => switch (self.buffer[self.index]) {
                '0'...'9',
                'A'...'Z',
                'a'...'z',
                => {
                    if (self.state == .state_attribute_value_single_quoted or
                        self.state == .state_attribute_value_double_quoted)
                    {
                        attribute.value_len += 1;
                    } else {
                        token.len += 1;
                    }

                    self.index += 1;
                    continue :s .state_entity_reference;
                },

                ';' => {
                    if (self.state == .state_attribute_value_single_quoted or
                        self.state == .state_attribute_value_double_quoted)
                    {
                        attribute.value_len += 1;
                    } else {
                        token.len += 1;
                    }

                    continue :s self.state;
                },

                else => {
                    token.tag = .character;
                    token.start = start_pos;
                    token.len = 1;

                    self.state = .state_data;
                    self.index = start_pos + 1;
                    break :s;
                },
            },

            .state_parameter_entity_reference => switch (self.buffer[self.index]) {
                ';' => {
                    if (self.state == .state_element_type_declaration_name) {
                        token.len += 1;
                    } else if (self.state == .state_element_type_before_declaration_content_spec) {
                        self.span.?.len += 1;
                    }

                    self.index += 1;
                    continue :s self.state;
                },
                else => {
                    if (isNameChar(self.buffer[self.index])) {
                        if (self.state == .state_element_type_declaration_name) {
                            token.len += 1;
                        } else if (self.state == .state_element_type_before_declaration_content_spec) {
                            self.span.?.len += 1;
                        }

                        self.index += 1;
                        continue :s .state_parameter_entity_reference;
                    }

                    @panic("not handled yet!");
                },
            },

            .state_tag_open => {
                const c = self.buffer[self.index];
                //self.debugByte();

                token.tag = .start_tag;
                token.start = self.index;

                if (isNameStartChar(c)) {
                    token.len += 1;
                    self.index += 1;

                    self.state = .state_tag_name;
                    continue :s .state_tag_name;
                }

                switch (c) {
                    '/' => {
                        self.index += 1;
                        self.state = .state_end_tag_open;
                        continue :s .state_end_tag_open;
                    },

                    '?' => {
                        // PI | XML Declaration | Text Declaration
                        // they're share the same prefix "<?"
                        self.index += 1;
                        self.state = .state_pi_target;
                        continue :s .state_pi_target;
                    },

                    '!' => {
                        self.index += 1;
                        continue :s .state_markup_declaration_open;
                    },

                    else => {
                        token.tag = .character;
                        token.start = start_pos;
                        token.len = 1;

                        self.state = .state_data;
                        self.index = start_pos + 1;
                        break :s;
                    },
                }
            },

            .state_tag_name => {
                if (self.index == self.buffer.len) {
                    self.state = .state_data;
                }

                const c = self.buffer[self.index];
                //self.debugByte();
                if (isNameChar(c)) {
                    token.len += 1;
                    self.index += 1;
                    continue :s .state_tag_name;
                }

                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        self.state = .state_before_attribute_name;
                        continue :s .state_before_attribute_name;
                    },

                    '/' => {
                        self.index += 1;
                        self.state = .state_self_closing_start_tag;
                        continue :s .state_self_closing_start_tag;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    else => {
                        token.tag = .character;
                        token.start = start_pos;
                        token.len = 1;

                        self.index = start_pos + 1;
                        self.state = .state_data;
                        break :s;
                    },
                }

                @panic("not implemented");
            },

            .state_end_tag_open => {
                const c = self.buffer[self.index];
                switch (c) {
                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        continue :s .state_data;
                    },
                    else => {
                        if (isNameStartChar(c)) {
                            token = .init(.end_tag, self.index, 1);

                            self.index += 1;
                            self.state = .state_tag_name;
                            continue :s .state_tag_name;
                        }

                        // TODO
                        // Parse error. Switch to the bogus comment state.
                        @panic("not implemented");
                    },
                }
            },

            .state_before_attribute_name => {
                if (self.index == self.buffer.len) {
                    self.state = .state_data;
                    continue :s .state_data;
                }

                // std.debug.print("{s} | ", .{"state_before_attribute_name"});
                // self.debugByte();
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_attribute_name;
                    },

                    '?' => {
                        self.index += 1;
                        continue :s self.state;
                    },

                    '/' => {
                        self.index += 1;
                        continue :s .state_self_closing_start_tag;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    else => {
                        if (!isNameStartChar(c)) {
                            @panic("illegal attribute name characters!");
                        }

                        // TODO Anything else
                        // Start a new attribute in the current tag token. Set that
                        // attribute's name to the current input character, and its
                        // value to the empty string. Switch to the attribute name state.
                        attribute.name_start = self.index;
                        attribute.name_len += 1;

                        self.index += 1;
                        // self.state = .state_attribute_name;
                        continue :s .state_attribute_name;
                    },
                }
            },

            .state_attribute_name => {
                if (self.index == self.buffer.len) {
                    self.state = .state_data;
                    continue :s self.state;
                }

                const c = self.buffer[self.index];
                //std.debug.print("{s} | ", .{"state_attribute_name"});
                //self.debugByte();

                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        self.state = .state_after_attribute_name;
                        continue :s .state_after_attribute_name;
                    },

                    '/' => {
                        self.index += 1;
                        self.state = .state_self_closing_start_tag;
                        continue :s .state_self_closing_start_tag;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    '=' => {
                        self.index += 1;
                        continue :s .state_before_attribute_value;
                    },

                    else => {
                        if (isNameChar(c)) {
                            attribute.name_len += 1;
                            self.index += 1;
                            continue :s .state_attribute_name;
                        }

                        @panic("not implemented");
                    },
                }
            },

            .state_after_attribute_name => {
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_after_attribute_name;
                    },

                    '=' => {
                        self.index += 1;
                        // self.state = .state_before_attribute_value;
                        continue :s .state_before_attribute_value;
                    },

                    '/' => {
                        if (attribute.name_len > 0) {
                            // TODO should be an invalid syntax here
                            // the attribte name has no meaning
                            @panic("found attribte name, has no value after it!");
                        }

                        attribute = .empty;

                        self.index += 1;
                        // self.state = .state_self_closing_start_tag;
                        continue :s .state_self_closing_start_tag;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },
                    else => {
                        @panic("not implemented");
                    },
                }
            },

            .state_before_attribute_value => {
                const c = self.buffer[self.index];

                // std.debug.print("{s} | ", .{"state_before_attribute_value"});
                //self.debugByte();
                switch (c) {
                    ' ', '\t', '\r', '\n' => { // Ignore the character.
                        self.index += 1;
                        continue :s .state_before_attribute_value;
                    },

                    '"' => {
                        attribute.value_start = self.index + 1;
                        self.index += 1;
                        continue :s .state_attribute_value_double_quoted;
                    },

                    '\'' => {
                        attribute.value_start = self.index + 1;
                        self.index += 1;
                        // self.state = .state_attribute_value_single_quoted;
                        continue :s .state_attribute_value_single_quoted;
                    },

                    '>' => {
                        // idk
                    },

                    // '<' forbidden inside attribute values
                    '<',
                    // '&' is allowed inside the attribute values
                    // BUT not as the first thing before choosing quotes
                    '&',
                    => {
                        @panic("forbidden character in attribute value, not implemented!");
                    },

                    else => {
                        // Anything else
                        // unquoted value
                        // <tag attr=value>
                        // this is valid in HTML
                        // BUT invalid in XML
                        // token.tag = .character;
                        // token.start = start_pos;
                        // token.len = 1;
                        //
                        // self.index = start_pos + 1;
                        // self.state = .state_data;
                        // break :s;
                        @panic("unquoted attribute value not allowed! not implemented!");
                    },
                }
            },

            .state_attribute_value_single_quoted => {
                const c = self.buffer[self.index];

                switch (c) {
                    0 => {
                        if (self.index == self.buffer.len) {
                            // token.tag = .character;
                            // token.start = start_pos;
                            // token.len = 1;
                            //
                            // self.index = start_pos + 1;
                            // self.state = .state_data;
                            // break :s;
                            @panic("unterminated!");
                        }

                        // its says
                        // "'" ([^<&"] | Reference)* "'"
                        attribute.value_len += 1;
                        self.index += 1;
                        continue :s .state_attribute_value_single_quoted;
                    },

                    '\'' => {
                        self.pushAttribute(attribute);
                        attribute = .empty;

                        self.index += 1;
                        continue :s .state_after_attribute_value;
                    },

                    '&' => {
                        self.index += 1;
                        self.state = .state_attribute_value_single_quoted;
                        continue :s .state_character_reference;
                    },

                    '<',
                    // '"', // maybe?
                    => {
                        @panic("illegal character '<' or '\"' inside attribute value!");
                    },

                    else => {
                        attribute.value_len += 1;
                        self.index += 1;
                        continue :s .state_attribute_value_single_quoted;
                    },
                }
            },

            .state_attribute_value_double_quoted => switch (self.buffer[self.index]) {
                0 => {
                    if (self.index == self.buffer.len) {
                        std.debug.print("eof found\n", .{});
                        //
                        // token.tag = .character;
                        // token.start = start_pos;
                        // token.len = 1;
                        //
                        // self.index = start_pos + 1;
                        // self.state = .state_data;
                        // break :s;
                        //
                        @panic("unterminated!");
                    }

                    // its says
                    // '"' ([^<&"] | Reference)* '"'
                    attribute.value_len += 1;
                    self.index += 1;
                    continue :s .state_attribute_value_double_quoted;
                },

                '"' => {
                    self.pushAttribute(attribute);
                    attribute = .empty;

                    self.index += 1;
                    continue :s .state_after_attribute_value;
                },

                '&' => {
                    self.index += 1;
                    self.state = .state_attribute_value_double_quoted;
                    continue :s .state_character_reference;
                },

                '<',
                // '\'', // maybe?
                => {
                    @panic("illegal character '<' or '\'' inside attribute value!");
                },

                else => {
                    attribute.value_len += 1;
                    self.index += 1;
                    continue :s .state_attribute_value_double_quoted;
                },
            },

            .state_after_attribute_value => switch (self.buffer[self.index]) {
                ' ', '\t', '\r', '\n' => {
                    self.index += 1;
                    continue :s .state_before_attribute_name;
                },

                '/' => {
                    self.index += 1;
                    continue :s .state_self_closing_start_tag;
                },

                '?' => {
                    self.index += 1;
                    continue :s self.state;
                },

                '>' => {
                    self.index += 1;
                    self.state = .state_data;
                    break :s;
                },

                else => {
                    if (self.index == self.buffer.len) {
                        continue :s .state_data;
                    }

                    self.index += 1;
                    continue :s .state_before_attribute_name;
                },
            },

            .state_self_closing_start_tag => {
                if (self.index == self.buffer.len) {
                    self.state = .state_data;
                    continue :s .state_data;
                }

                if (self.buffer[self.index] == '>') {
                    self.index += 1;

                    self.state = .state_data;
                    token.tag = .start_tag_self_closing;

                    break :s;
                }

                // TODO
                // Anything else
                // Parse error. Reconsume the character in the before attribute name state.

                @panic("not implemented");
            },

            .state_markup_declaration_open => {
                //self.debugByte();
                // If the next two characters are both U+002D HYPHEN-MINUS characters (-), consume those two characters, create a comment token whose data is the empty string, and switch to the comment start state.
                if (self.index + 1 < self.buffer.len and
                    std.mem.eql(u8, self.buffer[self.index .. self.index + 2], "--"))
                {
                    token.tag = .comment;
                    token.start = self.index + 2;
                    std.debug.print("it's a comment start dash\n", .{});
                    self.index += 2;
                    continue :s .state_comment_start;
                }

                // Otherwise, if the next seven characters are an ASCII case-insensitive match for the word "DOCTYPE", then consume those characters and switch to the DOCTYPE state.
                if (self.index + 6 < self.buffer.len and
                    std.ascii.eqlIgnoreCase(
                        self.buffer[self.index .. self.index + 7],
                        "doctype",
                    ))
                {
                    self.index += 7;
                    self.state = .state_doctype;
                    continue :s .state_doctype;
                }

                // Otherwise, if the insertion mode is "in foreign content"
                // and the current node is not an element in the HTML namespace
                // and the next seven characters are an case-sensitive match for
                // the string "[CDATA[" (the five uppercase letters "CDATA" with
                // a U+005B LEFT SQUARE BRACKET character before and after),
                // then consume those characters and switch to the CDATA section state.
                if (self.index + 6 < self.buffer.len and
                    std.mem.eql(
                        u8,
                        self.buffer[self.index .. self.index + 7],
                        "[CDATA[",
                    ))
                {
                    token.tag = .cdata;
                    token.start = self.index + 7;

                    self.index += 7;
                    self.state = .state_cdata_section;
                    continue :s .state_cdata_section;
                }

                if (self.index + 6 < self.buffer.len and
                    std.mem.eql(
                        u8,
                        self.buffer[self.index .. self.index + 7],
                        "ELEMENT",
                    ))
                {
                    token.tag = .element_declaration;

                    self.index += 7;
                    self.state = .state_element_type_declaration_start;
                    continue :s .state_element_type_declaration_start;
                }

                // Otherwise, this is a parse error.
                // Switch to the bogus comment state. The next character that is consumed,
                // if any, is the first character that will be in the comment.
                @panic("TODO: not handled yet!");
            },

            .state_comment_start => {
                // std.debug.print("{s} | ", .{"state_comment_start"});
                //self.debugByte();
                switch (self.buffer[self.index]) {
                    '-' => {
                        // Consume the next input character:
                        // U+002D HYPHEN-MINUS (-)
                        //     Switch to the comment start dash state.

                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                        }

                        self.index += 1;
                        continue :s .state_comment_start_dash;
                    },

                    0 => {
                        // EOF
                        //  Parse error.
                        //  Emit the comment token.
                        //  Reconsume the EOF character in the data state.
                        if (self.index == self.buffer.len) {
                            if (mode == .internal_subset) {
                                self.identifier.?.internal_subset_len += 1;
                                self.index += 1;
                                continue :s self.state;
                            }

                            self.index += 1;
                            self.state = .state_data;
                            break :s;
                        }

                        // U+0000 NULL
                        //     Parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the comment token's data. Switch to the comment state.

                        self.index += 1;
                        continue :s .state_comment;
                    },

                    '>' => {
                        // U+003E GREATER-THAN SIGN (>)
                        //     Parse error. Switch to the data state.
                        //     Emit the comment token.

                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s self.state;
                        }

                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    else => {
                        // Anything else
                        //  Append the current input character to the comment token's data.
                        //  Switch to the comment state.
                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s .state_comment;
                        }

                        token.len += 1;
                        self.index += 1;
                        continue :s .state_comment;
                    },
                }
            },

            .state_comment_start_dash => {
                const c = self.buffer[self.index];
                // Consume the next input character:
                // std.debug.print("{s} | ", .{"state_comment_start_dash"});
                //self.debugByte();

                switch (c) {
                    '-' => {
                        // U+002D HYPHEN-MINUS (-)
                        //     Switch to the comment end state

                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                        }

                        self.index += 1;
                        continue :s .state_comment_end;
                    },

                    0 => {
                        if (self.index == self.buffer.len) {
                            // EOF
                            //  Parse error.
                            //  Emit the comment token.
                            //  Reconsume the EOF character in the data state.

                            if (mode == .internal_subset) {
                                self.identifier.?.internal_subset_len += 1;
                                self.index += 1;
                                continue :s self.state;
                            }

                            self.state = .state_data;
                            break :s;
                        }

                        // U+0000 NULL
                        //     Parse error.
                        //     Append a U+002D HYPHEN-MINUS character (-) and
                        //     a U+FFFD REPLACEMENT CHARACTER
                        //     character to the comment token's data.
                        //     Switch to the comment state.
                        @panic("not handled!");
                    },

                    '>' => {
                        // U+003E GREATER-THAN SIGN (>)
                        //     Parse error. Switch to the data state.
                        //     Emit the comment token.

                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s self.state;
                        }

                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    else => {
                        // Anything else
                        //     Append a U+002D HYPHEN-MINUS character (-) and the current input character to the comment token's data. Switch to the comment state.
                        @panic("not handled!");
                    },
                }
            },

            .state_comment => {
                // 8.2.4.48 Comment state
                // Consume the next input character:
                const c = self.buffer[self.index];
                //std.debug.print("{s} | ", .{"state_comment"});
                self.debugByte();
                switch (c) {
                    '-' => {
                        // U+002D HYPHEN-MINUS (-)
                        //     Switch to the comment end dash state
                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                        }

                        self.index += 1;
                        continue :s .state_comment_end_dash;
                    },

                    0 => {
                        if (self.index == self.buffer.len) {
                            // EOF
                            // Parse error.
                            // Emit the comment token.
                            // Reconsume the EOF character in the data state.

                            if (mode == .internal_subset) {
                                self.identifier.?.internal_subset_len += 1;
                                self.index += 1;
                                continue :s self.state;
                            }

                            self.state = .state_data;
                            break :s;
                        }

                        // U+0000 NULL
                        //  Parse error.
                        //  Append a U+FFFD REPLACEMENT CHARACTER character to the comment token's data.
                        @panic("not handled yet!");
                    },

                    else => {
                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s .state_comment;
                        }

                        // Anything else
                        //  Append the current input character to the comment token's data.
                        token.len += 1;
                        self.index += 1;
                        continue :s .state_comment;
                    },
                }
            },

            .state_comment_end_dash => {
                // 8.2.4.49 Comment end dash state
                // Consume the next input character:
                const c = self.buffer[self.index];
                // std.debug.print("{s} | ", .{"state_comment_end_dash"});
                // self.debugByte();

                switch (c) {
                    // U+002D HYPHEN-MINUS (-)
                    //     Switch to the comment end state
                    '-' => {
                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                        }

                        self.index += 1;
                        continue :s .state_comment_end;
                    },

                    0 => {
                        if (self.index == self.buffer.len) {
                            // EOF
                            //     Parse error. Emit the comment token. Reconsume the EOF character in the data state.
                            if (mode == .internal_subset) {
                                self.identifier.?.internal_subset_len += 1;
                                self.index += 1;
                                continue :s self.state;
                            }

                            self.state = .state_data;
                            break :s;
                        }

                        // U+0000 NULL
                        //     Parse error. Append a U+002D HYPHEN-MINUS character (-) and a U+FFFD REPLACEMENT CHARACTER character to the comment token's data. Switch to the comment state.
                        @panic("not handled yet!");
                    },
                    // Anything else
                    //     Append a U+002D HYPHEN-MINUS character (-) and the current input character to the comment token's data. Switch to the comment state.
                    else => {
                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s .state_comment;
                        }

                        token.len += 1;
                        self.index += 1;
                        continue :s .state_comment;
                    },
                }
                @panic("not implemented!");
            },

            .state_comment_end => {
                const c = self.buffer[self.index];
                // std.debug.print("{s} | ", .{"state_comment_end"});
                // self.debugByte();
                switch (c) {
                    '>' => {
                        // U+003E GREATER-THAN SIGN (>)
                        //  Switch to the data state. Emit the comment token.
                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s self.state;
                        }

                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },
                    0 => {
                        // EOF
                        //  Parse error. Emit the comment token. Reconsume the EOF character in the data state.
                        // U+0000 NULL
                        //  Parse error. Append two U+002D HYPHEN-MINUS characters (-) and a U+FFFD REPLACEMENT CHARACTER character to the comment token's data. Switch to the comment state.
                    },
                    '!' => {
                        // U+0021 EXCLAMATION MARK (!)
                        //  Parse error. Switch to the comment end bang state.
                        self.index += 1;
                        continue :s .state_comment_end_bang;
                    },
                    '-' => {
                        // U+002D HYPHEN-MINUS (-)
                        //  Parse error. Append a U+002D HYPHEN-MINUS character (-) to the comment token's data.
                    },
                    else => {
                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s .state_comment;
                        }

                        token.len += 1;
                        self.index += 1;
                        continue :s .state_comment;

                        // Anything else
                        //  Parse error. Append two U+002D HYPHEN-MINUS characters (-) and the current input character to the comment token's data. Switch to the comment state.
                    },
                }
                @panic("not implemented!");
            },

            .state_comment_end_bang => {
                const c = self.buffer[self.index];
                switch (c) {

                    // U+002D HYPHEN-MINUS (-)
                    //     Append two U+002D HYPHEN-MINUS characters (-) and a U+0021 EXCLAMATION MARK character (!) to the comment token's data. Switch to the comment end dash state.
                    '>' => {
                        // U+003E GREATER-THAN SIGN (>)
                        //     Switch to the data state. Emit the comment token.

                        if (mode == .internal_subset) {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s self.state;
                        }

                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },
                    0 => {
                        // U+0000 NULL
                        //     Parse error. Append two U+002D HYPHEN-MINUS characters (-), a U+0021 EXCLAMATION MARK character (!), and a U+FFFD REPLACEMENT CHARACTER character to the comment token's data. Switch to the comment state.
                        // EOF
                        //     Parse error. Emit the comment token. Reconsume the EOF character in the data state.
                    },
                    else => {
                        // Anything else
                        //     Append two U+002D HYPHEN-MINUS characters (-), a U+0021 EXCLAMATION MARK character (!), and the current input character to the comment token's data. Switch to the comment state.
                    },
                }

                @panic("not implemented!");
            },

            .state_doctype => {
                const c = self.buffer[self.index];
                //self.debugByte();
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_doctype_name;
                    },
                    else => {
                        if (self.index == self.buffer.len) {
                            // EOF
                            //  Parse error. Create a new DOCTYPE token.
                            //  Set its force-quirks flag to on. Emit the token.
                            //  Reconsume the EOF character in the data state.
                            @panic("not handled yet!");
                        }

                        // Anything else
                        //     Parse error. Reconsume the character in the before DOCTYPE name state.
                        continue :s .state_before_doctype_name;
                    },
                }
            },

            .state_before_doctype_name => {
                const c = self.buffer[self.index];
                self.debugByte();
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_doctype_name;
                    },

                    0 => {
                        if (self.index == self.buffer.len) {
                            // EOF
                            //     Parse error. Create a new DOCTYPE token. Set its force-quirks flag to on. Emit the token. Reconsume the EOF character in the data state.
                            @panic("not handled yet!");
                        }

                        // U+0000 NULL
                        //     Parse error. Set the token's name to a U+FFFD REPLACEMENT CHARACTER character. Switch to the DOCTYPE name state.
                        @panic("illegal \x00 character inside doctype");
                    },

                    '>' => {
                        // U+003E GREATER-THAN SIGN (>)
                        //     Parse error.
                        //     Create a new DOCTYPE token.
                        //     Set its force-quirks flag to on.
                        //     Switch to the data state. Emit the token.
                        @panic("not handled yet!");
                    },

                    else => {
                        if (isNameChar(c)) {
                            token.tag = .doctype;
                            token.len += 1;
                            token.start = self.index;

                            self.index += 1;
                            self.state = .state_doctype_name;
                            continue :s .state_doctype_name;
                        }

                        // Anything else
                        //     Create a new DOCTYPE token. Set the token's name to the current input character. Switch to the DOCTYPE name state.
                        // continue :s .state_before_doctype_name;
                        @panic("not handled yet!");
                    },
                }
            },

            .state_doctype_name => {
                const c = self.buffer[self.index];
                self.debugByte();
                switch (c) {
                    // U+0009 CHARACTER TABULATION
                    // U+000A LINE FEED (LF)
                    // U+000C FORM FEED (FF)
                    // U+0020 SPACE
                    //     Switch to the after DOCTYPE name state.
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_after_doctype_name;
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    //     Switch to the data state. Emit the current DOCTYPE token.
                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    // U+0000 NULL
                    //  Parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current DOCTYPE token's name.
                    // EOF
                    //  Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                    0 => {
                        if (self.index == self.buffer[self.index]) {}
                        @panic("not handled yet!");
                    },

                    else => {
                        if (isNameChar(c)) {
                            token.len += 1;
                            self.index += 1;
                            continue :s .state_doctype_name;
                        }

                        // Anything else
                        //     Append the current input character to the current DOCTYPE token's name.
                        @panic("not handled yet!");
                    },
                }
            },

            .state_after_doctype_name => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    // U+0009 CHARACTER TABULATION
                    // U+000A LINE FEED (LF)
                    // U+000C FORM FEED (FF)
                    // U+0020 SPACE
                    //     Ignore the character.
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_after_doctype_name;
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    //     Switch to the data state.
                    //     Emit the current DOCTYPE token.
                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    '[' => {
                        self.identifier = .empty;
                        self.identifier.?.internal_subset_start = self.index + 1;

                        self.index += 1;
                        self.state = .state_doctype_internal_subset;
                        continue :s .state_doctype_internal_subset;
                    },

                    else => {
                        // EOF
                        //  Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                        if (self.index == self.buffer.len) {
                            @panic("not handled yet!");
                        }

                        // Anything else

                        // If the six characters starting from the current input character are an ASCII case-insensitive match
                        // for the word "PUBLIC", then consume those characters and switch to the after DOCTYPE public keyword state.
                        if (self.index + 5 < self.buffer.len and std.ascii.eqlIgnoreCase(self.buffer[self.index .. self.index + 6], "public")) {
                            self.index += 6;
                            continue :s .state_after_doctype_public_keyword;
                        }

                        // Otherwise, if the six characters starting from the current input character are an ASCII case-insensitive match
                        // for the word "SYSTEM", then consume those characters and switch to the after DOCTYPE system keyword state.
                        if (self.index + 5 < self.buffer.len and std.ascii.eqlIgnoreCase(self.buffer[self.index .. self.index + 6], "system")) {
                            self.index += 6;
                            continue :s .state_after_doctype_system_keyword;
                        }

                        // Otherwise, this is the parse error.
                        // Set the DOCTYPE token's force-quirks flag to on. Switch to the bogus DOCTYPE state.
                        @panic("not handled yet!");
                    },
                }
            },

            .state_after_doctype_public_keyword => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    // U+0009 CHARACTER TABULATION
                    // U+000A LINE FEED (LF)
                    // U+000C FORM FEED (FF)
                    // U+0020 SPACE
                    //  Switch to the before DOCTYPE public identifier state.
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_doctype_public_identifier;
                    },

                    // U+0022 QUOTATION MARK (")
                    //  Parse error. Set the DOCTYPE token's public identifier to the empty string (not missing), then switch to the DOCTYPE public identifier (double-quoted) state.
                    '"' => {
                        self.identifier = .empty;
                        self.identifier.?.public_start = self.index + 1;

                        self.index += 1;
                        continue :s .state_doctype_public_identifier_double_quoted;
                    },

                    // U+0027 APOSTROPHE (')
                    //  Parse error. Set the DOCTYPE token's public identifier to the empty string (not missing),
                    //  then switch to the DOCTYPE public identifier (single-quoted) state.
                    '\'' => {
                        self.identifier = .empty;
                        self.identifier.?.public_start = self.index + 1;

                        self.index += 1;
                        continue :s .state_doctype_public_identifier_single_quoted;
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    //  Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit that DOCTYPE token.

                    '>' => {},

                    else => {
                        // EOF
                        // Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                        if (self.index >= self.buffer.len) {}

                        // Anything else
                        // Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the bogus DOCTYPE state.
                        @panic("not handled yet!");
                    },
                }
            },

            .state_before_doctype_public_identifier => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_doctype_system_identifier;
                    },

                    '"' => {
                        self.identifier = .empty;
                        self.identifier.?.public_start.? = self.index + 1;

                        self.index += 1;
                        continue :s .state_doctype_public_identifier_double_quoted;
                    },

                    '\'' => {
                        self.identifier = .empty;
                        self.identifier.?.public_start.? = self.index + 1;

                        self.index += 1;
                        continue :s .state_doctype_public_identifier_single_quoted;
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit that DOCTYPE token.
                    '>' => {
                        @panic("not handled yet!");
                    },

                    // EOF
                    //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                    // Anything else
                    //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the bogus DOCTYPE state.
                    else => {
                        @panic("not handled yet!");
                    },
                }
            },

            .state_doctype_public_identifier_double_quoted => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    '"' => {
                        self.index += 1;
                        continue :s .state_after_doctype_public_identifier;
                    },

                    0 => {
                        @panic("not handled yet!");
                    },

                    '>' => {
                        @panic("not handled yet!");
                    },

                    else => {
                        if (isPubidChar(c)) {
                            self.identifier.?.public_len.? += 1;
                            self.index += 1;
                            continue :s .state_doctype_public_identifier_double_quoted;
                        }

                        @panic("not handled yet!");
                    },
                }
            },

            .state_doctype_public_identifier_single_quoted => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    '\'' => {
                        self.index += 1;
                        continue :s .state_after_doctype_public_identifier;
                    },

                    0 => {
                        @panic("not handled yet!");
                    },

                    '>' => {
                        @panic("not handled yet!");
                    },

                    else => {
                        if (isPubidChar(c)) {
                            self.identifier.?.public_len.? += 1;
                            self.index += 1;
                            continue :s .state_doctype_public_identifier_double_quoted;
                        }

                        @panic("not handled yet!");
                    },
                }
            },

            .state_after_doctype_public_identifier => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    // U+0009 CHARACTER TABULATION
                    // U+000A LINE FEED (LF)
                    // U+000C FORM FEED (FF)
                    // U+0020 SPACE
                    // Switch to the between DOCTYPE public and system identifiers state.
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_between_doctype_public_and_system_identifiers;
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    //     Switch to the data state. Emit the current DOCTYPE token.
                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    // U+0022 QUOTATION MARK (")
                    // Parse error. Set the DOCTYPE token's system identifier to the empty string (not missing),
                    // then switch to the DOCTYPE system identifier (double-quoted) state.
                    '"' => {
                        self.identifier.?.system_start = self.index + 1;
                        self.index += 1;
                        continue :s .state_doctype_system_identifier_double_quoted;
                    },

                    // U+0027 APOSTROPHE (')
                    //     Parse error. Set the DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (single-quoted) state.
                    '\'' => {
                        self.identifier.?.system_start = self.index + 1;
                        self.index += 1;
                        continue :s .state_doctype_system_identifier_double_quoted;
                    },

                    else => {
                        // EOF
                        //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                        if (self.index == self.buffer.len) {
                            @panic("not handled yet!");
                        }

                        // Anything else
                        //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the bogus DOCTYPE state.
                        @panic("not handled yet!");
                    },
                }
            },

            .state_between_doctype_public_and_system_identifiers => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    // U+0009 CHARACTER TABULATION
                    // U+000A LINE FEED (LF)
                    // U+000C FORM FEED (FF)
                    // U+0020 SPACE
                    //     Ignore the character.
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_between_doctype_public_and_system_identifiers;
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    //     Switch to the data state. Emit the current DOCTYPE token.
                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    // U+0022 QUOTATION MARK (")
                    //     Set the DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (double-quoted) state.
                    '"' => {
                        self.identifier.?.system_start = self.index + 1;

                        self.index += 1;
                        continue :s .state_doctype_system_identifier_double_quoted;
                    },

                    // U+0027 APOSTROPHE (')
                    //     Set the DOCTYPE token's system identifier to the empty string (not missing), then switch to the DOCTYPE system identifier (single-quoted) state.
                    '\'' => {
                        self.identifier.?.system_start = self.index + 1;
                        self.index += 1;
                        continue :s .state_doctype_system_identifier_single_quoted;
                    },

                    // EOF
                    //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                    // Anything else
                    //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the bogus DOCTYPE state.

                    else => {
                        // EOF
                        //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                        if (self.index == self.buffer.len) {
                            @panic("not handled yet!");
                        }

                        // Anything else
                        //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the bogus DOCTYPE state.
                        @panic("not handled yet!");
                    },
                }
            },

            .state_after_doctype_system_keyword => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_doctype_system_identifier;
                    },

                    '"' => {
                        self.identifier = .empty;
                        self.identifier.?.system_start = self.index + 1;

                        self.index += 1;
                        continue :s .state_doctype_system_identifier_double_quoted;
                    },

                    '\'' => {
                        self.identifier = .empty;
                        self.identifier.?.system_start = self.index + 1;

                        self.index += 1;
                        continue :s .state_doctype_system_identifier_single_quoted;
                    },

                    else => {
                        @panic("not handled yet!");
                    },
                }
            },

            .state_before_doctype_system_identifier => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_doctype_system_identifier;
                    },

                    '"' => {
                        self.identifier = .empty;
                        self.identifier.?.system_start = self.index + 1;
                        self.index += 1;
                        continue :s .state_doctype_system_identifier_double_quoted;
                    },

                    '\'' => {
                        self.identifier = .empty;
                        self.identifier.?.system_start = self.index + 1;
                        self.index += 1;
                        continue :s .state_doctype_system_identifier_single_quoted;
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit that DOCTYPE token.
                    '>' => {
                        @panic("not handled yet!");
                    },

                    // EOF
                    //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                    // Anything else
                    //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the bogus DOCTYPE state.
                    else => {
                        @panic("not handled yet!");
                    },
                }
            },

            .state_doctype_system_identifier_double_quoted => {
                const c = self.buffer[self.index];
                self.debugByte();
                switch (c) {
                    // U+0022 QUOTATION MARK (")
                    // Switch to the after DOCTYPE system identifier state.
                    '"' => {
                        self.index += 1;
                        continue :s .state_after_doctype_system_identifier;
                    },

                    // U+0000 NULL
                    // Parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current DOCTYPE token's system identifier.
                    0 => {
                        // EOF
                        // Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                        if (self.index >= self.buffer.len) {
                            @panic("not handled yet!");
                        }

                        @panic("not handled yet!");
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    // Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit that DOCTYPE token.
                    '>' => {
                        @panic("not handled yet!");
                    },

                    else => {
                        // Anything else
                        //  Append the current input character to the current DOCTYPE token's system identifier.

                        self.identifier.?.system_len += 1;
                        self.index += 1;
                        continue :s .state_doctype_system_identifier_double_quoted;
                    },
                }
            },

            .state_doctype_system_identifier_single_quoted => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    // U+0022 QUOTATION MARK (")
                    // Switch to the after DOCTYPE system identifier state.
                    '\'' => {
                        self.index += 1;
                        continue :s .state_after_doctype_system_identifier;
                    },

                    // U+0000 NULL
                    // Parse error. Append a U+FFFD REPLACEMENT CHARACTER character to the current DOCTYPE token's system identifier.
                    0 => {
                        // EOF
                        // Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                        if (self.index >= self.buffer.len) {
                            @panic("not handled yet!");
                        }

                        @panic("not handled yet!");
                    },

                    // U+003E GREATER-THAN SIGN (>)
                    // Parse error. Set the DOCTYPE token's force-quirks flag to on. Switch to the data state. Emit that DOCTYPE token.
                    '>' => {
                        @panic("not handled yet!");
                    },

                    else => {
                        // Anything else
                        //  Append the current input character to the current DOCTYPE token's system identifier.

                        self.identifier.?.system_len += 1;
                        self.index += 1;
                        continue :s .state_doctype_system_identifier_double_quoted;
                    },
                }
            },

            .state_after_doctype_system_identifier => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_after_doctype_system_identifier;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    '[' => {
                        // Start of internal subset
                        self.identifier.?.internal_subset_start = self.index + 1;

                        self.index += 1;
                        self.state = .state_doctype_internal_subset;
                        continue :s .state_doctype_internal_subset;
                    },

                    else => {
                        // EOF
                        //     Parse error. Set the DOCTYPE token's force-quirks flag to on. Emit that DOCTYPE token. Reconsume the EOF character in the data state.
                        // Anything else
                        //     Parse error. Switch to the bogus DOCTYPE state. (This does not set the DOCTYPE token's force-quirks flag to on.)
                        @panic("not handled yet!");
                    },
                }
            },

            .state_doctype_internal_subset => {
                const c = self.buffer[self.index];
                self.debugByte();

                switch (c) {
                    '\'' => {
                        self.index += 1;
                        self.identifier.?.internal_subset_len += 1;
                        continue :s .state_doctype_internal_subset_string_single_quoted;
                    },

                    '"' => {
                        self.index += 1;
                        self.identifier.?.internal_subset_len += 1;
                        continue :s .state_doctype_internal_subset_string_double_quoted;
                    },

                    ']' => {
                        self.index += 1;
                        continue :s .state_after_doctype_system_identifier;
                    },

                    '<' => {
                        // <!-- ... --->
                        if (self.index + 1 < self.buffer.len and self.buffer[self.index + 1] == '!') {
                            self.identifier.?.internal_subset_len += 1;
                            self.index += 1;
                            continue :s .state_doctype_internal_subset_comment;
                        }

                        self.identifier.?.internal_subset_len += 1;
                        self.index += 1;
                        continue :s .state_doctype_internal_subset;
                    },

                    else => {
                        // ignore everything
                        self.identifier.?.internal_subset_len += 1;
                        self.index += 1;
                        continue :s .state_doctype_internal_subset;
                    },
                }
            },

            .state_doctype_internal_subset_string_double_quoted => switch (self.buffer[self.index]) {
                '"' => {
                    self.identifier.?.internal_subset_len += 1;
                    self.index += 1;
                    continue :s .state_doctype_internal_subset;
                },
                else => {
                    self.identifier.?.internal_subset_len += 1;
                    self.index += 1;
                    continue :s .state_doctype_internal_subset_string_double_quoted;
                },
            },

            .state_doctype_internal_subset_string_single_quoted => switch (self.buffer[self.index]) {
                '\'' => {
                    self.identifier.?.internal_subset_len += 1;
                    self.index += 1;
                    continue :s .state_doctype_internal_subset;
                },
                else => {
                    self.identifier.?.internal_subset_len += 1;
                    self.index += 1;
                    continue :s .state_doctype_internal_subset_string_single_quoted;
                },
            },

            .state_doctype_internal_subset_comment => {
                self.debugByte();

                if (self.index + 1 < self.buffer.len and
                    self.buffer[self.index + 1] == '-' and
                    self.buffer[self.index + 2] == '-')
                {
                    mode = .internal_subset;
                    self.identifier.?.internal_subset_len += 3;
                    std.debug.print("it's a internal_subset comment start dash\n", .{});
                    self.index += 3;
                    std.debug.print("next: {c}\n", .{self.buffer[self.index]});
                    continue :s .state_comment_start;
                }

                self.identifier.?.internal_subset_len += 1;
                self.index += 1;
                continue :s .state_doctype_internal_subset;
            },

            .state_bogus_doctype => {
                @panic("not handled yet!");
            },

            .state_cdata_section => {
                if (self.index == self.buffer.len) {
                    // If the end of the file was reached, reconsume the EOF character.
                    self.state = .state_data;
                    break :s;
                }

                const cdata_len = scanCData(self.buffer[self.index..], 0) catch |err| switch (err) {
                    error.UnexpectedEOF => {
                        token.tag = .character;
                        token.start = start_pos;
                        token.len = 1;
                        self.index = start_pos + 1;
                        self.state = .state_data;
                        break :s;
                    },
                    else => {

                        // TODO
                        // not sure what the action for now, have so many option here
                        // - propagate errors instead of panicking
                        // - attach location info
                        // - optionally recover, but carefully
                        // - always advance the cursor on failure
                        @panic("TODO not handled yet; invalid cdata!");
                    },
                };

                std.debug.print("cdata_len: {}\n", .{cdata_len});
                token.len += cdata_len;

                // consume closing sequence ']]>' + consume next index
                self.index += cdata_len + 3;
                self.state = .state_data;
                break :s;
            },

            .state_pi_target => {
                if (self.index >= self.buffer.len) {
                    @panic("UnexpectedEOF");
                }

                // PITarget must be a Name and not (xml | XML) reserved for A
                // standardization in this or future version on xml spec.
                if (!isNameStartChar(self.buffer[self.index])) {
                    @panic("invalid PI Target");
                }

                // assume it's pi token
                token = .init(.pi, self.index, 1);
                // consume "NameStartChar"
                self.index += 1;

                while (self.index < self.buffer.len and isNameChar(self.buffer[self.index])) {
                    token.len += 1;
                    self.index += 1;
                }

                const name = self.buffer[token.start..self.index];

                // check for name eq to 'xml' (case insensiteve)
                // then must be XMLDecl or TextDecl depending on context
                if (std.ascii.eqlIgnoreCase(name, "xml")) {
                    token = .init(.xml_declaration, token.start, token.len);
                    self.state = .state_xml_declaration;
                    continue :s .state_xml_declaration;
                }

                self.span = .empty;
                self.span.?.start = self.index;
                continue :s .state_before_pi_data;
            },

            .state_before_pi_data => switch (self.buffer[self.index]) {
                ' ', '\t', '\r', '\n' => {
                    self.index += 1;
                    continue :s .state_before_pi_data;
                },
                else => {
                    if (isChar(self.buffer[self.index])) {
                        self.span.?.start = self.index;
                        self.state = .state_pi_data;
                        continue :s .state_pi_data;
                    }
                    @panic("not handled!");
                },
            },

            .state_pi_data => {
                // self.debugByte();
                const c = self.buffer[self.index];
                switch (c) {
                    '?' => {
                        // maybe the close sequence
                        self.index += 1;
                        continue :s .state_pi_close;
                    },

                    0 => {},

                    else => {
                        if (isChar(c)) {
                            self.span.?.len += 1;

                            self.index += 1;
                            continue :s .state_pi_data;
                        }

                        // maybe the close sequence
                        @panic("not handled yet!");
                    },
                }
            },

            .state_pi_close => switch (self.buffer[self.index]) {
                '>' => {
                    self.index += 1;
                    self.state = .state_data;
                    break :s;
                },
                else => {
                    self.span.?.len += 1;
                    continue :s .state_pi_data;
                },
            },

            .state_xml_declaration => {
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_xml_declaration;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    else => {
                        if (self.index + 6 < self.buffer.len and
                            std.mem.eql(u8, self.buffer[self.index .. self.index + 7], "version"))
                        {
                            self.state = .state_xml_declaration;
                            continue :s .state_before_attribute_name;
                        }

                        @panic("not implemented");
                    },
                }
            },

            .state_element_type_declaration_start => {
                // '<!ELEMENT' S Name S contentspec
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_element_type_declaration_name;
                    },
                    else => {
                        @panic("not handled yet!");
                    },
                }
            },

            .state_before_element_type_declaration_name => {
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_before_element_type_declaration_name;
                    },
                    '%' => {
                        self.state = .state_element_type_declaration_name;
                        continue :s .state_element_type_declaration_name;
                    },
                    else => {
                        if (isNameChar(c)) {
                            token.start = self.index;
                            token.len += 1;

                            self.index += 1;
                            self.state = .state_element_type_declaration_name;
                            continue :s .state_element_type_declaration_name;
                        }

                        @panic("not handled yet!");
                    },
                }
            },

            .state_element_type_declaration_name => {
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_after_element_type_declaration_name;
                    },

                    '%' => {
                        token.start = self.index;
                        self.index += 1;
                        continue :s .state_parameter_entity_reference;
                    },

                    else => {
                        if (isNameChar(c)) {
                            token.len += 1;
                            self.index += 1;
                            continue :s .state_element_type_declaration_name;
                        }

                        @panic("not handled yet!");
                    },
                }
            },

            .state_after_element_type_declaration_name => {
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_after_element_type_declaration_name;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    else => {
                        // contentspec
                        // 'EMPTY' | 'ANY' | Mixed | children
                        std.debug.print("isChar({c}) {} | {s}\n", .{ c, isChar(c), "state_after_element_type_declaration_name" });
                        if (isChar(c)) {
                            self.span = .empty;
                            self.span.?.start = self.index;
                            continue :s .state_element_type_before_declaration_content_spec;
                        }

                        @panic("not handled yet!");
                    },
                }
            },

            .state_element_type_before_declaration_content_spec => {
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_after_element_type_declaration_name;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;

                        break :s;
                    },

                    '%' => {
                        self.span = .empty;
                        self.span.?.start = self.index;
                        self.span.?.len += 1;
                        self.index += 1;

                        self.state = .state_element_type_before_declaration_content_spec;
                        continue :s .state_parameter_entity_reference;
                    },

                    '(' => {
                        std.debug.print("it's grouped\n", .{});
                        // grouped
                        self.span.?.len += 1;
                        self.index += 1;
                        continue :s .state_element_type_declaration_content_spec_grouped;
                    },

                    else => {
                        std.debug.print("isNameChar({c}) {} | {s}\n", .{ c, isNameChar(c), "state_element_type_before_declaration_content_spec" });
                        if (isNameChar(c)) {
                            // maybe literal?
                            self.span.?.len += 1;
                            self.index += 1;
                            continue :s .state_element_type_declaration_content_spec_literal;
                        }

                        @panic("not handled yet!");
                    },
                }
            },

            .state_element_type_declaration_content_spec_literal => {
                const c = self.buffer[self.index];
                switch (c) {
                    ' ', '\t', '\r', '\n' => {
                        self.index += 1;
                        continue :s .state_after_element_type_declaration_name;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    else => {
                        if (isNameChar(c)) {
                            self.span.?.len += 1;
                            self.index += 1;
                            continue :s .state_element_type_declaration_content_spec_literal;
                        }

                        @panic("not handled yet!");
                    },
                }
            },

            .state_element_type_declaration_content_spec_grouped => {
                const c = self.buffer[self.index];
                switch (c) {
                    '(' => {
                        continue :s .state_element_type_before_declaration_content_spec;
                    },

                    ')' => {
                        self.span.?.len += 1;
                        self.index += 1;
                        continue :s .state_element_type_declaration_content_spec_grouped_quantifier;
                    },

                    '>' => {
                        self.index += 1;
                        self.state = .state_data;
                        break :s;
                    },

                    else => {
                        std.debug.print("isChar({c}) {} | {s}\n", .{ c, isChar(c), "state_element_type_declaration_content_spec_grouped" });
                        if (isChar(c)) {
                            self.span.?.len += 1;
                            self.index += 1;
                            continue :s .state_element_type_declaration_content_spec_grouped;
                        }

                        @panic("not handled yet!");
                    },
                }
            },

            .state_element_type_declaration_content_spec_grouped_quantifier => switch (self.buffer[self.index]) {
                '?', '*', '+' => {
                    self.span.?.len += 1;
                    self.index += 1;
                    continue :s .state_element_type_declaration_content_spec_grouped_quantifier;
                },

                ' ', '\t', '\r', '\n' => {
                    self.index += 1;
                    continue :s .state_after_element_type_declaration_name;
                },

                '>' => {
                    self.index += 1;
                    self.state = .state_data;
                    break :s;
                },

                else => {
                    self.span.?.len += 1;
                    self.index += 1;
                    continue :s .state_element_type_declaration_content_spec_grouped;
                },
            },

            // else => {
            //     std.debug.print("{t}\n", .{self.state});
            //     @panic("not implemented!");
            // },
        }

        return token;
    }

    fn pushAttribute(self: *Tokenizer, attr: Attribute) void {
        if (self.attribute_elements_count == self.attribute_elements.len) {
            @panic("BufferOverflow");
        }

        return null;
    }

    /// 2.2 Characters
    /// [Definition: A parsed entity contains text, a sequence of characters,
    /// which may represent markup or character data.]
    /// [Definition: A character is an atomic unit of text as specified by
    /// ISO/IEC 10646:2000 [ISO/IEC 10646].
    /// Legal characters are tab, carriage return, line feed, and the legal
    /// characters of Unicode and ISO/IEC 10646. The versions of these
    /// standards cited in A.1 Normative References were current at the time
    /// this document was prepared. New characters may be added to these
    /// standards by amendments or new editions. Consequently, XML processors
    /// MUST accept any character in the range specified for Char. ]
    ///
    /// Character Range
    /// [2] Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
    fn isChar(c: u21) bool {
        return switch (c) {
            0x9,
            0xA,
            0xD,
            0x20...0xD7FF,
            0xE000...0xFFFD,
            0x10000...0x10FFFF,
            => true,
            else => false,
        };
    }

    fn isPubidPunctuation(c: u21) bool {
        return switch (c) {
            '-', '\'', '(', ')', '+', ',', '.', '/', ':', '=', '?', ';', '!', '*', '#', '@', '$', '_', '%' => true,
            else => false,
        };
    }

    fn isPubidChar(c: u21) bool {
        return switch (c) {
            0x20,
            0xD,
            0xA,
            '0'...'9',
            'A'...'Z',
            'a'...'z',
            => true,
            else => isPubidPunctuation(c),
        };
    }

    fn validateUtf8(input: [:0]const u8) bool {
        return (!std.unicode.utf8ValidateSlice(input));
    }

    fn peekExpectEqualStrings(self: *Tokenizer, comptime v: []const u8) bool {
        return self.index + v.len - 1 < self.buffer.len and
            std.mem.eql(
                u8,
                self.buffer[self.index .. self.index + v.len],
                v,
            );
    }

    /// Scan a CDATA section starting at `start` (right after `!<[CDATA[`).
    /// Returns the byte slice of the CDATA content and the index right
    /// after closing sequence `]]>`.
    fn scanCData(buffer: []const u8, start: usize) !u16 {
        var i: usize = start;
        var bracket_count: u2 = 0;

        while (i < buffer.len) {
            const b = buffer[i];

            // Fast path: most bytes land here
            if (b != ']' and b != '>') {
                bracket_count = 0;

                if (b < 0x80) {
                    if (!isChar(b)) return error.InvalidChar;
                    i += 1;
                    continue;
                }

                const len = try std.unicode.utf8ByteSequenceLength(b);
                if (i + len > buffer.len) return error.InvalidUtf8;

                const seq = buffer[i .. i + len];
                const cp = std.unicode.utf8Decode(seq) catch return error.InvalidUtf8;

                if (!isChar(cp)) return error.InvalidChar;

                i += len;
                continue;
            }

            // Slow path: delimiter handling
            if (b == ']') {
                if (bracket_count < 2) bracket_count += 1;
                i += 1;
                continue;
            }

            // b == '>'
            if (bracket_count == 2) {
                return @intCast(i - 2);
            }

            bracket_count = 0;
            i += 1;
        }

        // EOF withot closing sequence
        return error.UnexpectedEOF;
    }

    /// [4] NameStartChar ::=
    ///     ":" | [A-Z] | "_" | [a-z] |
    ///     [#xC0-#xD6] |
    ///     [#xD8-#xF6] |
    ///     [#xF8-#x2FF] |
    ///     [#x370-#x37D] |
    ///     [#x37F-#x1FFF] |
    ///     [#x200C-#x200D] |
    ///     [#x2070-#x218F] |
    ///     [#x2C00-#x2FEF] |
    ///     [#x3001-#xD7FF] |
    ///     [#xF900-#xFDCF] |
    ///     [#xFDF0-#xFFFD] |
    ///     [#x10000-#xEFFFF]
    fn isNameStartChar(c: u21) bool {
        return switch (c) {
            ':',
            '_',
            'A'...'Z',
            'a'...'z',
            // Partial Unicode ranges (u8 limited)
            0xC0...0xD6,
            0xD8...0xF6,
            0xF8...0x2FF,
            0x370...0x37D,
            0x37F...0x1FFF,
            0x200C...0x200D,
            0x2070...0x218F,
            0x2C00...0x2FEF,
            0x3001...0xD7FF,
            0xF900...0xFDCF,
            0xFDF0...0xFFFD,
            0x10000...0xEFFFF,
            => true,
            else => false,
        };
    }

    fn isNameChar(v: u21) bool {
        return switch (v) {
            '-', '.' => true,
            '0'...'9' => true,
            0xB7,
            0x300...0x36F,
            => true,
            else => return isNameStartChar(v),
        };
    }

    fn isAttValue(v: u21) bool {
        // except "<&"
        return switch (v) {
            '<', '&' => return false,
            else => return true,
        };
    }

    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debug.print("{f} | [0x{x}] \"{s}\" | attrs_len={}\n", .{
            token,
            self.buffer[token.start .. token.start + token.len],
            self.buffer[token.start .. token.start + token.len],
            self.kv_count,
        });
    }

    pub fn debugByte(self: *Tokenizer) void {
        std.debug.print("'{c}' [0x{X}] | {t}\n", .{
            self.buffer[self.index],
            self.buffer[self.index],
            self.state,
        });
    }
};

test "isNameChar" {
    // try std.testing.expect(Tokenizer.isChar('%'));
    // try std.testing.expect(Tokenizer.isChar(';'));
    // try std.testing.expect(Tokenizer.isChar('('));
    // try std.testing.expect(Tokenizer.isChar(')'));
    // try std.testing.expect(Tokenizer.isChar('|'));
    // try std.testing.expect(Tokenizer.isChar('?'));
    // try std.testing.expect(Tokenizer.isChar('*'));
    // try std.testing.expect(Tokenizer.isChar('+'));
}

test "scan CDATA" {
    const buffer = "<![CDATA[abcdefg]]>";
    const cdata_len = try Tokenizer.scanCData(buffer[8..], 0);
    std.debug.print("cdata: {}\n", .{cdata_len});
}

fn testTokenizer(source: [:0]const u8, expected_tags: []const Token.Tag) !void {
    // for (source, 0..) |c, i| {
    //     std.debug.print("{c};{}\n", .{ c, i });
    // }
    std.debug.print("\ncase: \"{s}\"\n", .{source});
    var tokenizer = Tokenizer.init(source);

    std.debug.print("tokens\n", .{});
    for (expected_tags) |tag| {
        const token = tokenizer.next();
        defer {
            tokenizer.dump(&token);

            const attrs = tokenizer.attributes();
            for (attrs) |attr| {
                attr.print(source);
            }

            if (token.tag == .pi) {
                std.debug.print("data \"{s}\"\n", .{tokenizer.process_instruction().?});
            }
        }

        try std.testing.expectEqual(tag, token.tag);
    }

    const last_token = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.eof, last_token.tag);
}

test "character" {
    try testTokenizer("\x00", &[_]Token.Tag{.character});

    try testTokenizer("&_;", &[_]Token.Tag{ .character, .character });
    try testTokenizer("&#65;", &[_]Token.Tag{.character});

    try testTokenizer("&#1A;", &[_]Token.Tag{ .character, .character });
    try testTokenizer("&#zz;", &[_]Token.Tag{ .character, .character });

    try testTokenizer("&#xA9;", &[_]Token.Tag{.character});
    try testTokenizer("&#x..;", &[_]Token.Tag{ .character, .character });

    try testTokenizer("&#x41;", &[_]Token.Tag{.character});
    try testTokenizer("&amp;", &[_]Token.Tag{.character});

    try testTokenizer("abc", &[_]Token.Tag{.character});
}

test "markup declarations" {
    try testTokenizer("<!-- ... -->", &[_]Token.Tag{.comment});
    try testTokenizer("<!-- _abc_ -->", &[_]Token.Tag{.comment});
    try testTokenizer("<!-- 1abc; -->", &[_]Token.Tag{.comment});
    try testTokenizer("<!-- Hello, World! -->", &[_]Token.Tag{.comment});
    try testTokenizer(
        \\<!-- 
        \\Hello,
        \\World!
        \\-->
    ,
        &[_]Token.Tag{.comment},
    );

    try testTokenizer("<![CDATA[abc]]>", &[_]Token.Tag{.cdata});
    try testTokenizer("<![CDATA[]]>", &[_]Token.Tag{.cdata});
    try testTokenizer("<![CDATA[&amp;]]>", &[_]Token.Tag{.cdata});
    try testTokenizer("<![CDATA[>", &[_]Token.Tag{ .character, .character });

    try testTokenizer(
        \\<![CDATA[
        \\Hello,
        \\World!
        \\]]>
    ,
        &[_]Token.Tag{.cdata},
    );

    try testTokenizer("<?abc hello_world?>", &[_]Token.Tag{.pi});
    try testTokenizer("<?def hello, there??>", &[_]Token.Tag{.pi});
    try testTokenizer("<?def a b c?>", &[_]Token.Tag{.pi});

    try testTokenizer("<?xml version=\"1.0\" encoding=\"utf-8\" ?>", &[_]Token.Tag{.xml_declaration});
    try testTokenizer("<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\" ?>", &[_]Token.Tag{.xml_declaration});

    try testTokenizer("<!DOCTYPE greeting SYSTEM \"hello.dtd\">", &[_]Token.Tag{.doctype});
    try testTokenizer(
        \\<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    , &[_]Token.Tag{.doctype});

    try testTokenizer(
        \\<!DOCTYPE greeting [
        \\  <!ELEMENT a (b > c)>
        \\] >
    , &[_]Token.Tag{.doctype});

    try testTokenizer(
        \\<!DOCTYPE greeting [
        \\  <!ELEMENT a "(b ] c)">
        \\] >
    , &[_]Token.Tag{.doctype});

    try testTokenizer(
        \\<!DOCTYPE greeting [
        \\  <!ELEMENT a (b > c)>
        \\  <!-- a comment with ] ,> ,--, ->. -->
        \\  <!ELEMENT a "(b ] c)">  <!-- this is invalid, but tokenizer wont care -->
        \\] >
    , &[_]Token.Tag{.doctype});

    try testTokenizer(
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<!DOCTYPE library [
        \\    <!ELEMENT library (book+)>
        \\    <!ELEMENT book (title, author, isbn)>
        \\    <!ELEMENT title (#PCDATA)>
        \\    <!ELEMENT author (#PCDATA)>
        \\    <!ELEMENT isbn (#PCDATA)>
        \\    <!ATTLIST book id ID #REQUIRED>
        \\]>
        \\<library>
        \\<book id="book1">
        \\<title>Learning XML</title>
        \\<author>John Doe</author>
        \\<isbn>978-1234567890</isbn>
        \\</book>
        \\</library>
    , &[_]Token.Tag{
        .xml_declaration,
        .character,
        .doctype,
        .character,

        // library
        .start_tag,
        .character,

        // book
        .start_tag,
        .character,

        // title
        .start_tag,
        .character,
        .end_tag,
        .character,

        // author
        .start_tag,
        .character,
        .end_tag,
        .character,

        // isbn
        .start_tag,
        .character,
        .end_tag,
        .character,

        // book
        .end_tag,
        .character,

        // library
        .end_tag,
    });

    try testTokenizer(
        \\<?xml version="1.0"?>
        \\<!DOCTYPE temperatures [
        \\   <!ELEMENT temperatures (filename, case)>
        \\   <!ELEMENT filename (#PCDATA)>
        \\   <!ELEMENT case EMPTY>
        \\   <!ATTLIST case 
        \\             date        CDATA  #REQUIRED
        \\             temperature CDATA  #IMPLIED>
        \\<]>
        \\<temperatures>
        \\   <filename>ISCCPMonthly_avg.nc</filename>
        \\   <case date="16-JAN-1994" 
        \\         temperature="278.9"/>
        \\</temperatures>
    , &[_]Token.Tag{
        .xml_declaration,
        .character,
        .doctype,
        .character,
        .start_tag,
        .character,
        .start_tag,
        .character,
        .end_tag,
        .character,
        .start_tag_self_closing,
        .character,
        .end_tag,
    });

    try testTokenizer("<!ELEMENT br EMPTY>", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT x (%good; | c)>", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT container ANY>", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT %name.para; %content.para; >", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT p (#PCDATA|emph)* >", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT spec (front, body, back?)>", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT div1 (head, (p | list | note)*, div2*)>", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT dictionary-body (%div.mix; | %dict.mix;)*>", &[_]Token.Tag{.element_declaration});

    try testTokenizer("<!ELEMENT p (#PCDATA|a|ul|b|i|em)*>", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT p (#PCDATA | %font; | %phrase; | %special; | %form;)* >", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT b (#PCDATA)>", &[_]Token.Tag{.element_declaration});
    try testTokenizer("<!ELEMENT topichead    %topichead.content;>", &[_]Token.Tag{.element_declaration});

    try testTokenizer(
        \\<!ELEMENT temperatures (variable,
        \\                        filename,
        \\                        filepath,
        \\                        subset,
        \\                        longitude,
        \\                        latitude,
        \\                        case*)>
    , &[_]Token.Tag{.element_declaration});

    // ATTLIST
    try testTokenizer("<!ATTLIST img >", &[_]Token.Tag{.attribute_list_declaration});

    // [CDATA attribute with default]
    try testTokenizer("<!ATTLIST square width CDATA \"0\">", &[_]Token.Tag{.attribute_list_declaration});

    // [#REQUIRED attribute]
    try testTokenizer("<!ATTLIST person number CDATA #REQUIRED>", &[_]Token.Tag{.attribute_list_declaration});

    // [#IMPLIED attribute]
    try testTokenizer("<!ATTLIST contact fax CDATA #IMPLIED>", &[_]Token.Tag{.attribute_list_declaration});

    // [#FIXED attribute]
    try testTokenizer("<!ATTLIST sender company CDATA #FIXED \"Zig Foundation\">", &[_]Token.Tag{.attribute_list_declaration});

    // /[Enumerated values]
    // <!ATTLIST payment type (check|cash) "cash">
    try testTokenizer("<!ATTLIST payment type (check|cash) \"cash\">", &[_]Token.Tag{.attribute_list_declaration});

    try testTokenizer(
        \\<!ATTLIST img
        \\          src    CDATA      #REQUIRED
        \\          id     ID         #IMPLIED
        \\          sort   CDATA      #FIXED "true"
        \\          print  (yes | no) "yes"
        \\>
    , &[_]Token.Tag{.attribute_list_declaration});
}

test "element" {
    try testTokenizer("<a", &[_]Token.Tag{ .character, .character });
    try testTokenizer("<a>", &[_]Token.Tag{.start_tag});
    try testTokenizer("</a>", &[_]Token.Tag{.end_tag});
    try testTokenizer("</>", &[_]Token.Tag{.eof});
    try testTokenizer("<a/>", &[_]Token.Tag{.start_tag_self_closing});

    try testTokenizer("<a   />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<>", &[_]Token.Tag{ .character, .character });

    try testTokenizer("<a b='c' />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a b = 'c' />", &[_]Token.Tag{.start_tag_self_closing});

    try testTokenizer("<a b=\"c\" />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a b=\"c\" b=\"d\" />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a b='c' i='1' />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a b='c' b='d' />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a b='\x00' />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a:b c='1' />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a c='1 &amp; 2' />", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a c='&__;' />", &[_]Token.Tag{
        .character,
        .character,
        .character,
        .character,
        .character,
        .character,
        .character,
        .character,
    });

    try testTokenizer(
        \\<a x='1
        \\'/>
    ,
        &[_]Token.Tag{.start_tag_self_closing},
    );

    try testTokenizer("<a x=\"He said 'hi'\"/>", &[_]Token.Tag{.start_tag_self_closing});
    try testTokenizer("<a x='He said \"hi\"'/>", &[_]Token.Tag{.start_tag_self_closing});
}

test "TODO invalid" {
    // invalid
    // try testTokenizer("<a 1b='1' />", &[_]Token.Tag{.start_tag_self_closing});
    // try testTokenizer("<a -b='1' />", &[_]Token.Tag{.start_tag_self_closing});
    // try testTokenizer("<a .b='1' />", &[_]Token.Tag{.start_tag_self_closing});

    // TODO handle different unicode
    // try testTokenizer("<a ΑΒ=\"1\"/>", &[_]Token.Tag{.start_tag_self_closing});
    // try testTokenizer("<a ą=\"1\"/>", &[_]Token.Tag{.start_tag_self_closing});
    // try testTokenizer("<a ॐ=\"1\"/>", &[_]Token.Tag{.start_tag_self_closing});

    // try testTokenizer("<a b= />", &[_]Token.Tag{ });

    // try testTokenizer("<a b=' />", &[_]Token.Tag{ });

    // TODO
    // try testTokenizer("<a b  />", &[_]Token.Tag{.start_tag_self_closing});

    // TODO BufferOverflow
    // try testTokenizer(
    //     \\<a
    //     \\a='1'
    //     \\b='2'
    //     \\c='3'
    //     \\d='4'
    //     \\e='5'
    //     \\f='6'
    //     \\g='7'
    //     \\h='8'
    //     \\i='9'
    //     \\j='10'
    //     \\k='11'
    //     \\l='12'
    //     \\m='13'
    //     \\n='14'
    //     \\o='15'
    //     \\p='16'
    //     \\q='17'
    //     \\/>
    // , &[_]Token.Tag{.start_tag_self_closing});
}
