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
        pi,
        doctype,
        xml_declaration,
        eof,
        unknown,
    };

    pub fn format(token: *const Token, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("{t} | {};{}", .{
            token.tag,
            token.start,
            token.start + token.len,
        });
    }
};
