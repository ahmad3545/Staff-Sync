using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using StaffSync.Api.Models;

namespace StaffSync.Api.Services;

public class PayrollPdfBuilder
{
    public byte[] Build(PayrollRecord record)
    {
        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Margin(30);
                page.Size(PageSizes.A4);

                page.Header().Row(row =>
                {
                    row.RelativeItem().Column(column =>
                    {
                        column.Item().Text("StaffSync Payslip").FontSize(18).Bold();
                        column.Item().Text($"User: {record.UserId}").FontSize(10);
                        column.Item().Text($"Period: {record.PeriodStartUtc:yyyy-MM-dd} to {record.PeriodEndUtc:yyyy-MM-dd}").FontSize(10);
                    });
                    row.ConstantItem(140).AlignRight().Text($"Generated: {record.CreatedAtUtc:yyyy-MM-dd}").FontSize(9);
                });

                page.Content().PaddingVertical(20).Column(column =>
                {
                    column.Item().LineHorizontal(1).LineColor(Colors.Grey.Lighten2);
                    column.Item().PaddingTop(10).Text("Payroll Summary").FontSize(12).Bold();
                    column.Item().PaddingTop(8).Table(table =>
                    {
                        table.ColumnsDefinition(columns =>
                        {
                            columns.RelativeColumn();
                            columns.ConstantColumn(120);
                        });

                        table.Cell().Element(CellStyle).Text("Base Salary");
                        table.Cell().Element(CellStyle).AlignRight().Text(FormatCurrency(record.BaseSalary));

                        table.Cell().Element(CellStyle).Text("Allowances");
                        table.Cell().Element(CellStyle).AlignRight().Text(FormatCurrency(record.Allowances));

                        table.Cell().Element(CellStyle).Text("Overtime Hours");
                        table.Cell().Element(CellStyle).AlignRight().Text(record.OvertimeHours.ToString("0.##"));

                        table.Cell().Element(CellStyle).Text("Overtime Rate");
                        table.Cell().Element(CellStyle).AlignRight().Text(FormatCurrency(record.OvertimeRate));

                        table.Cell().Element(CellStyle).Text("Deductions");
                        table.Cell().Element(CellStyle).AlignRight().Text(FormatCurrency(record.Deductions));

                        table.Cell().Element(CellStyle).Text("Net Salary").Bold();
                        table.Cell().Element(CellStyle).AlignRight().Text(FormatCurrency(record.NetSalary)).Bold();

                        static IContainer CellStyle(IContainer container)
                        {
                            return container.BorderBottom(1).BorderColor(Colors.Grey.Lighten3).PaddingVertical(6);
                        }
                    });

                    column.Item().PaddingTop(16).Text("Status: " + record.Status).FontSize(10);
                });

                page.Footer().AlignCenter().Text("StaffSync Workforce Management").FontSize(9).FontColor(Colors.Grey.Darken1);
            });
        });

        return document.GeneratePdf();
    }

    private static string FormatCurrency(decimal value)
    {
        return $"PKR {value:N2}";
    }
}
