using System.Text;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace StaffSync.Api.Services;

public class ExportService
{
    public byte[] GenerateCsv(IReadOnlyList<IDictionary<string, object>> rows)
    {
        var builder = new StringBuilder();
        if (rows.Count == 0)
        {
            return Encoding.UTF8.GetBytes(string.Empty);
        }

        var headers = rows.SelectMany(r => r.Keys).Distinct().ToList();
        builder.AppendLine(string.Join(",", headers.Select(EscapeCsv)));

        foreach (var row in rows)
        {
            var values = headers.Select(h => row.TryGetValue(h, out var value) ? EscapeCsv(FormatValue(value)) : "");
            builder.AppendLine(string.Join(",", values));
        }

        return Encoding.UTF8.GetBytes(builder.ToString());
    }

    public byte[] GeneratePdf(string title, IReadOnlyList<IDictionary<string, object>> rows)
    {
        var headers = rows.Count == 0 ? new List<string>() : rows.SelectMany(r => r.Keys).Distinct().ToList();

        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Margin(30);
                page.Size(PageSizes.A4);

                page.Header().Text(title).FontSize(16).Bold();
                page.Content().PaddingTop(12).Table(table =>
                {
                    table.ColumnsDefinition(columns =>
                    {
                        foreach (var _ in headers)
                        {
                            columns.RelativeColumn();
                        }
                    });

                    foreach (var header in headers)
                    {
                        table.Cell().Element(CellHeaderStyle).Text(header).FontSize(9).Bold();
                    }

                    foreach (var row in rows)
                    {
                        foreach (var header in headers)
                        {
                            var value = row.TryGetValue(header, out var data) ? FormatValue(data) : string.Empty;
                            table.Cell().Element(CellBodyStyle).Text(value).FontSize(8);
                        }
                    }

                    static IContainer CellHeaderStyle(IContainer container)
                    {
                        return container.Background(Colors.Grey.Lighten3).Padding(4).BorderBottom(1).BorderColor(Colors.Grey.Lighten1);
                    }

                    static IContainer CellBodyStyle(IContainer container)
                    {
                        return container.Padding(4).BorderBottom(1).BorderColor(Colors.Grey.Lighten3);
                    }
                });
            });
        });

        return document.GeneratePdf();
    }

    private static string EscapeCsv(string value)
    {
        if (value.Contains('"'))
        {
            value = value.Replace("\"", "\"\"");
        }

        if (value.Contains(',') || value.Contains('\n') || value.Contains('\r'))
        {
            return $"\"{value}\"";
        }

        return value;
    }

    private static string FormatValue(object? value)
    {
        if (value == null)
        {
            return string.Empty;
        }

        return value switch
        {
            DateTime date => date.ToString("yyyy-MM-dd HH:mm:ss"),
            _ => value.ToString() ?? string.Empty
        };
    }
}
