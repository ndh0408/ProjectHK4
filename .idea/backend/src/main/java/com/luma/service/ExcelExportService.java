package com.luma.service;

import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.repository.RegistrationRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ExcelExportService {

    private final RegistrationRepository registrationRepository;
    private final EventService eventService;

    public byte[] exportEventAttendees(Event event) {
        try {
            return exportEventRegistrations(event.getId());
        } catch (IOException e) {
            throw new RuntimeException("Error exporting Excel file", e);
        }
    }

    public byte[] exportEventRegistrations(UUID eventId) throws IOException {
        var event = eventService.getEntityById(eventId);
        List<Registration> registrations = registrationRepository.findByEventAndStatus(event, RegistrationStatus.APPROVED);

        try (Workbook workbook = new XSSFWorkbook()) {
            Sheet sheet = workbook.createSheet("Attendee List");

            CellStyle headerStyle = workbook.createCellStyle();
            Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(IndexedColors.LIGHT_BLUE.getIndex());
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            Row headerRow = sheet.createRow(0);
            String[] headers = {"No.", "Full Name", "Email", "Phone", "Ticket Code", "Registration Date", "Status"};
            for (int i = 0; i < headers.length; i++) {
                Cell cell = headerRow.createCell(i);
                cell.setCellValue(headers[i]);
                cell.setCellStyle(headerStyle);
            }

            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
            int rowNum = 1;
            for (Registration reg : registrations) {
                Row row = sheet.createRow(rowNum);
                row.createCell(0).setCellValue(rowNum);
                row.createCell(1).setCellValue(reg.getUser().getFullName());
                row.createCell(2).setCellValue(reg.getUser().getEmail());
                row.createCell(3).setCellValue(reg.getUser().getPhone() != null ? reg.getUser().getPhone() : "");
                row.createCell(4).setCellValue(reg.getTicketCode());
                row.createCell(5).setCellValue(reg.getCreatedAt().format(formatter));
                row.createCell(6).setCellValue(reg.getStatus().name());
                rowNum++;
            }

            for (int i = 0; i < headers.length; i++) {
                sheet.autoSizeColumn(i);
            }

            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            workbook.write(outputStream);
            return outputStream.toByteArray();
        }
    }
}
