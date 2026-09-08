import os
import sys
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

def build_pdf():
    pdf_filename = "Testerio_Gedimai_XLE.pdf"

    # Register font supporting Lithuanian accents
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font_bold_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

    pdfmetrics.registerFont(TTFont("DejaVu", font_path))
    pdfmetrics.registerFont(TTFont("DejaVu-Bold", font_bold_path))

    doc = SimpleDocTemplate(
        pdf_filename,
        pagesize=landscape(A4),
        leftMargin=8 * mm,
        rightMargin=8 * mm,
        topMargin=8 * mm,
        bottomMargin=8 * mm
    )

    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        'TitleStyle',
        parent=styles['Normal'],
        fontName='DejaVu-Bold',
        fontSize=12,
        leading=14,
        textColor=colors.HexColor('#1A2530'),
        spaceAfter=4
    )

    header_style = ParagraphStyle(
        'HeaderStyle',
        parent=styles['Normal'],
        fontName='DejaVu-Bold',
        fontSize=7,
        leading=8.5,
        alignment=1, # Center
        textColor=colors.whitesmoke
    )

    cell_style = ParagraphStyle(
        'CellStyle',
        parent=styles['Normal'],
        fontName='DejaVu',
        fontSize=6.5,
        leading=8,
        textColor=colors.HexColor('#222222')
    )

    cell_bold_style = ParagraphStyle(
        'CellBoldStyle',
        parent=styles['Normal'],
        fontName='DejaVu-Bold',
        fontSize=6.5,
        leading=8,
        textColor=colors.HexColor('#111111')
    )

    cell_center_style = ParagraphStyle(
        'CellCenterStyle',
        parent=styles['Normal'],
        fontName='DejaVu',
        fontSize=6.5,
        leading=8,
        alignment=1,
        textColor=colors.HexColor('#222222')
    )

    data_rows = [
        ("10", "Prietaiso QR kodo nuskaitymas", "", "", "", "", "", ""),
        ("21", "Įžeminimo nuotėkio testas", "", "", "", "10.0 - 200.0 MΩ", "", ""),
        ("22", "Aukštos įtampos testas (Flash)", "Sureguliuoti kondensatoriai", "", "", "0.0 - 5.0 mA", "", ""),
        ("23", "Maitinimo izoliacijos varžos (DC) testas", "Elementai", "", "", "2.00 - 500.0 MΩ", "", ""),
        ("30", "Prietaiso įjungimas", "", "", "", "0.001KW - 3.000KW", "", ""),
        ("31", "Bluetooth PIN nuskaitymas naudojant OCR", "Įkrovimo valdiklis", "", "", "", "", ""),
        ("32", "Prietaiso paieška per Bluetooth", "Vartotojo sąsaja (UI)", "", "", "", "", ""),
        ("33", "Prisijungimas prie prietaiso per Bluetooth", "", "", "", "", "", ""),
        ("34", "Prietaiso galios nuskaitymas", "Įkrovimo valdiklis", "", "", "0.001KW - 0.015KW", "", ""),
        ("35", "PĮ UI versijos nuskaitymas iš prietaiso per Bluetooth", "Įkrovimo valdiklis", "", "", "", "", ""),
        ("36", "Datos ir laiko įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("37", "Datos ir laiko nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("38", "Ne piko maitinimo aptikimas per Bluetooth", "Įkrovimo valdiklis", "", "", "", "", ""),
        ("40", "1-ojo termistoriaus nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("41", "2-ojo termistoriaus nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("42", "3-ojo termistoriaus nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("50", "TRIAC įjungimas per Bluetooth", "", "", "", "", "", ""),
        ("51", "Prietaiso galios nuskaitymas", "Viršutiniai du elementai / Patikrinti laidus", "0.525KW - 0.735KW", "0.800KW - 1.155KW", "1.140KW - 1.620KW", "1.450KW - 2.000KW", "1.700KW - 2.420KW"),
        ("52", "Prietaiso galios nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("53", "TRIAC išjungimas per Bluetooth", "", "", "", "", "", ""),
        ("54", "Prietaiso budėjimo režimo galios nuskaitymas", "", "", "", "0.001KW - 0.012KW", "", ""),
        ("55", "1-osios relės įjungimas per Bluetooth", "", "", "", "", "", ""),
        ("56", "TRIAC 2 įjungimas per Bluetooth", "", "", "", "", "", ""),
        ("57", "Prietaiso galios nuskaitymas", "Apatinis elementas / Įkrovimo valdiklis", "0.315KW - 0.378KW", "0.400KW - 0.600KW", "0.666KW - 0.780KW", "0.820KW - 0.970KW", "0.990KW - 1.160KW"),
        ("58", "Prietaiso galios nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("59", "TRIAC 2 išjungimas per Bluetooth", "", "", "", "", "", ""),
        ("61", "1-osios relės išjungimas per Bluetooth", "", "", "", "", "", ""),
        ("62", "Ventiliatoriaus greičio įrašymas per Bluetooth", "", "", "", "", "", ""),
        ("63", "Ventiliatoriaus įjungimas per Bluetooth", "", "", "", "", "", ""),
        ("64", "Prietaiso galios nuskaitymas", "Ventiliatorius / Įkrovimo valdiklis", "", "", "0.011KW - 0.022KW", "", ""),
        ("65", "Ventiliatoriaus išjungimas per Bluetooth", "", "", "", "", "", ""),
        ("66", "Prietaiso budėjimo režimo galios nuskaitymas", "", "", "", "0.001KW - 0.011KW", "", ""),
        ("70", "UI foninio apšvietimo nustatymas į raudoną per Bluetooth", "", "", "", "", "", ""),
        ("71", "UI foninio apšvietimo spalvos nuskaitymas po 1 sek.", "", "", "", "", "", ""),
        ("72", "UI foninio apšvietimo nustatymas į žalią per Bluetooth", "", "", "", "", "", ""),
        ("73", "UI foninio apšvietimo spalvos nuskaitymas po 1 sek.", "", "", "", "", "", ""),
        ("74", "UI foninio apšvietimo nustatymas į mėlyną per Bluetooth", "", "", "", "", "", ""),
        ("75", "UI foninio apšvietimo spalvos nuskaitymas po 1 sek.", "", "", "", "", "", ""),
        ("80", "Šifravimo rakto įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("81", "Autentifikavimo rakto įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("82", "PIN kodo įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("83", "Aparatinės įrangos (HW) UI/ACC versijos įrašymas per Bluetooth", "", "", "", "", "", ""),
        ("84", "Aparatinės įrangos (HW) UI/ACC versijos įrašymas per Bluetooth", "", "", "", "", "", ""),
        ("85", "Prekės ženklo įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("86", "Šildytuvo tipo įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("87", "Apšvietimo konfigūracijos įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("88", "Galios apkrovos įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("89", "Šildytuvo dydžio įrašymas per Bluetooth", "", "", "", "", "", ""),
        ("90", "Ventiliatoriaus greičių įrašymas per Bluetooth", "", "", "", "", "", ""),
        ("91", "EMS kodo nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("92", "Identifikatoriaus nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("93", "Kontrolinės sumos nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("94", "Pagaminimo datos nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("95", "PĮ modifikacijos nuskaitymas per Bluetooth", "", "", "", "", "", ""),
        ("97", "GDID įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("98", "EOLT režimo išjungimo įrašymas į prietaisą per Bluetooth", "", "", "", "", "", ""),
        ("99", "QR kodo etikečių spausdinimas", "", "", "", "", "", ""),
        ("100", "Testas baigtas: Prietaisas išjungtas", "", "", "", "", "", "")
    ]

    headers = [
        Paragraph("<b>ID</b>", header_style),
        Paragraph("<b>Testo pavadinimas / Aprašymas</b>", header_style),
        Paragraph("<b>Sprendimas / Remontas</b>", header_style),
        Paragraph("<b>50</b>", header_style),
        Paragraph("<b>70</b>", header_style),
        Paragraph("<b>100</b>", header_style),
        Paragraph("<b>125</b>", header_style),
        Paragraph("<b>150</b>", header_style),
    ]

    table_data = [headers]

    for row in data_rows:
        test_id, name, fix, v50, v70, v100, v125, v150 = row

        id_p = Paragraph(test_id, cell_center_style)
        name_p = Paragraph(name, cell_bold_style if test_id in ["10", "100"] else cell_style)
        fix_p = Paragraph(fix, cell_style)
        v50_p = Paragraph(v50, cell_center_style)
        v70_p = Paragraph(v70, cell_center_style)
        v100_p = Paragraph(v100, cell_center_style)
        v125_p = Paragraph(v125, cell_center_style)
        v150_p = Paragraph(v150, cell_center_style)

        table_data.append([id_p, name_p, fix_p, v50_p, v70_p, v100_p, v125_p, v150_p])

    # Printable width: A4 landscape = 297mm - 16mm = 281mm
    col_widths = [10 * mm, 85 * mm, 52 * mm, 26.8 * mm, 26.8 * mm, 26.8 * mm, 26.8 * mm, 26.8 * mm]

    table_style = TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2C3E50')),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#A0A0A0')),
        ('TOPPADDING', (0, 0), (-1, -1), 1.5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 1.5),
        ('LEFTPADDING', (0, 0), (-1, -1), 2),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2),
    ])

    # Add alternating row background
    for i in range(1, len(table_data)):
        if i % 2 == 0:
            table_style.add('BACKGROUND', (0, i), (-1, i), colors.HexColor('#F8F9FA'))

    # Handle merged cells for 100-200 MOmega or single value spans if applicable
    # Note: Row index in table_data is row_idx + 1 because row 0 is header.
    # Row 21 (data_rows[1]): 10.0 - 200.0 MOmega spans across cols 3 to 7 (50..150)
    # Row 22 (data_rows[2]): 0.0 - 5.0 mA spans across cols 3 to 7
    # Row 23 (data_rows[3]): 2.00 - 500.0 MOmega spans cols 3 to 7
    # Row 30 (data_rows[4]): 0.001KW - 3.000KW spans cols 3 to 7
    # Row 34 (data_rows[8]): 0.001KW - 0.015KW spans cols 3 to 7
    # Row 54 (data_rows[20]): 0.001KW - 0.012KW spans cols 3 to 7
    # Row 64 (data_rows[29]): 0.011KW - 0.022KW spans cols 3 to 7
    # Row 66 (data_rows[31]): 0.001KW - 0.011KW spans cols 3 to 7

    span_row_indices = [1, 2, 3, 4, 8, 20, 29, 31]
    for idx in span_row_indices:
        r = idx + 1
        table_style.add('SPAN', (5, r), (7, r)) # merge 100 to 150 or 50 to 150 depending on visual
        # Actually in original table: value is placed under 100 column, spanning across 50-150.
        table_style.add('SPAN', (3, r), (7, r))

    t = Table(table_data, colWidths=col_widths, repeatRows=1)
    t.setStyle(table_style)

    elements = []
    title = Paragraph("<b>Testerio Gedimai XLE (Tester Failures XLE)</b>", title_style)
    elements.append(title)
    elements.append(Spacer(1, 2 * mm))
    elements.append(t)

    doc.build(elements)
    print("PDF generated successfully: " + pdf_filename)

if __name__ == '__main__':
    build_pdf()
