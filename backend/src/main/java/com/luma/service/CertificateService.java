package com.luma.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.itextpdf.io.image.ImageData;
import com.itextpdf.io.image.ImageDataFactory;
import com.itextpdf.kernel.colors.ColorConstants;
import com.itextpdf.kernel.colors.DeviceRgb;
import com.itextpdf.kernel.font.PdfFont;
import com.itextpdf.kernel.font.PdfFontFactory;
import com.itextpdf.kernel.geom.PageSize;
import com.itextpdf.kernel.pdf.PdfDocument;
import com.itextpdf.kernel.pdf.PdfWriter;
import com.itextpdf.layout.Document;
import com.itextpdf.layout.borders.Border;
import com.itextpdf.layout.element.Cell;
import com.itextpdf.layout.element.Image;
import com.itextpdf.layout.element.Paragraph;
import com.itextpdf.layout.element.Table;
import com.itextpdf.layout.properties.HorizontalAlignment;
import com.itextpdf.layout.properties.TextAlignment;
import com.itextpdf.layout.properties.UnitValue;
import com.itextpdf.layout.properties.VerticalAlignment;
import com.itextpdf.kernel.pdf.canvas.PdfCanvas;
import com.itextpdf.kernel.geom.Rectangle;
import com.itextpdf.layout.borders.SolidBorder;
import com.luma.dto.response.CertificateResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Certificate;
import com.luma.entity.Event;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.CertificateRepository;
import com.luma.repository.RegistrationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class CertificateService {

    private final CertificateRepository certificateRepository;
    private final RegistrationRepository registrationRepository;
    private final Cloudinary cloudinary;

    @Value("${app.base-url:http://localhost:8080}")
    private String baseUrl;

    private static final String CERTIFICATE_CODE_PREFIX = "CERT-";
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("MMMM dd, yyyy");
    private static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("h:mm a");

    @Transactional
    public CertificateResponse generateCertificate(UUID registrationId) {
        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));

        validateCertificateEligibility(registration);

        if (certificateRepository.existsByRegistration(registration)) {
            Certificate existing = certificateRepository.findByRegistration(registration)
                    .orElseThrow();
            return CertificateResponse.fromEntity(existing);
        }

        String certificateCode = generateCertificateCode();

        byte[] pdfBytes = generateCertificatePdf(registration, certificateCode);

        String certificateUrl = uploadPdfToCloudinary(pdfBytes, certificateCode);

        Certificate certificate = Certificate.builder()
                .registration(registration)
                .certificateCode(certificateCode)
                .certificateUrl(certificateUrl)
                .generatedAt(LocalDateTime.now())
                .build();

        certificate = certificateRepository.save(certificate);
        log.info("Certificate generated for registration {} with code {}", registrationId, certificateCode);

        return CertificateResponse.fromEntity(certificate);
    }

    public CertificateResponse getCertificateByRegistration(UUID registrationId, User user) {
        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));

        if (!registration.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only access your own certificates");
        }

        validateCertificateEligibility(registration);

        Certificate certificate = certificateRepository.findByRegistration(registration)
                .orElseGet(() -> {
                    CertificateResponse response = generateCertificate(registrationId);
                    return certificateRepository.findById(response.getId()).orElseThrow();
                });

        return CertificateResponse.fromEntity(certificate);
    }

    public PageResponse<CertificateResponse> getUserCertificates(User user, Pageable pageable) {
        Page<Certificate> certificates = certificateRepository.findByUser(user, pageable);

        return PageResponse.<CertificateResponse>builder()
                .content(certificates.map(CertificateResponse::fromEntity).getContent())
                .page(certificates.getNumber())
                .size(certificates.getSize())
                .totalElements(certificates.getTotalElements())
                .totalPages(certificates.getTotalPages())
                .last(certificates.isLast())
                .build();
    }

    public PageResponse<CertificateResponse> getOrganiserCertificates(User organiser, Pageable pageable) {
        Page<Certificate> certificates = certificateRepository.findByOrganiser(organiser, pageable);

        return PageResponse.<CertificateResponse>builder()
                .content(certificates.map(CertificateResponse::fromEntity).getContent())
                .page(certificates.getNumber())
                .size(certificates.getSize())
                .totalElements(certificates.getTotalElements())
                .totalPages(certificates.getTotalPages())
                .last(certificates.isLast())
                .build();
    }

    public PageResponse<CertificateResponse> getEventCertificates(UUID eventId, User organiser, Pageable pageable) {
        Page<Certificate> certificates = certificateRepository.findByEventId(eventId, pageable);

        if (!certificates.isEmpty()) {
            Certificate first = certificates.getContent().get(0);
            if (!first.getRegistration().getEvent().getOrganiser().getId().equals(organiser.getId())) {
                throw new BadRequestException("You can only view certificates for your own events");
            }
        }

        return PageResponse.<CertificateResponse>builder()
                .content(certificates.map(CertificateResponse::fromEntity).getContent())
                .page(certificates.getNumber())
                .size(certificates.getSize())
                .totalElements(certificates.getTotalElements())
                .totalPages(certificates.getTotalPages())
                .last(certificates.isLast())
                .build();
    }

    public CertificateResponse verifyCertificate(String code) {
        Certificate certificate = certificateRepository.findByCertificateCode(code)
                .orElseThrow(() -> new ResourceNotFoundException("Certificate not found or invalid"));

        return CertificateResponse.fromEntity(certificate);
    }

    public byte[] downloadCertificate(UUID certificateId, User user) {
        Certificate certificate = certificateRepository.findById(certificateId)
                .orElseThrow(() -> new ResourceNotFoundException("Certificate not found"));

        if (!certificate.getRegistration().getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only download your own certificates");
        }

        return generateCertificatePdf(certificate.getRegistration(), certificate.getCertificateCode());
    }

    public byte[] getCertificatePdfByCode(String code) {
        Certificate certificate = certificateRepository.findByCertificateCode(code)
                .orElseThrow(() -> new ResourceNotFoundException("Certificate not found"));

        return generateCertificatePdf(certificate.getRegistration(), certificate.getCertificateCode());
    }

    public boolean isEligibleForCertificate(Registration registration) {
        try {
            validateCertificateEligibility(registration);
            return true;
        } catch (BadRequestException e) {
            return false;
        }
    }

    private void validateCertificateEligibility(Registration registration) {
        Event event = registration.getEvent();

        if (registration.getStatus() != RegistrationStatus.APPROVED) {
            throw new BadRequestException("Registration must be approved to receive certificate");
        }

        if (registration.getCheckedInAt() == null) {
            throw new BadRequestException("You must check in to the event to receive certificate");
        }

        if (event.getEndTime() == null || event.getEndTime().isAfter(LocalDateTime.now())) {
            throw new BadRequestException("Event has not ended yet");
        }
    }

    private String generateCertificateCode() {
        String code;
        do {
            code = CERTIFICATE_CODE_PREFIX + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        } while (certificateRepository.findByCertificateCode(code).isPresent());
        return code;
    }

    private byte[] generateCertificatePdf(Registration registration, String certificateCode) {
        Event event = registration.getEvent();
        User user = registration.getUser();

        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            PdfWriter writer = new PdfWriter(baos);
            PdfDocument pdf = new PdfDocument(writer);
            Document document = new Document(pdf, PageSize.A4.rotate());

            DeviceRgb blueColor = new DeviceRgb(41, 171, 226);
            DeviceRgb darkColor = new DeviceRgb(45, 45, 45);
            DeviceRgb grayColor = new DeviceRgb(80, 80, 80);

            PdfFont boldFont = PdfFontFactory.createFont("Helvetica-Bold");
            PdfFont regularFont = PdfFontFactory.createFont("Helvetica");
            PdfFont italicFont = PdfFontFactory.createFont("Helvetica-BoldOblique");

            Rectangle pageSize = pdf.getDefaultPageSize();
            float pageWidth = pageSize.getWidth();
            float pageHeight = pageSize.getHeight();

            PdfCanvas canvas = new PdfCanvas(pdf.addNewPage());

            float arrowMiddleY = pageHeight / 2;

            canvas.setFillColor(blueColor);
            canvas.rectangle(0, pageHeight - 50, 12, 50);
            canvas.fill();

            canvas.rectangle(0, 0, 12, 50);
            canvas.fill();

            float darkBaseWidth = 140;
            float darkPointX = 220;

            canvas.setFillColor(darkColor);
            canvas.moveTo(0, pageHeight - 50);
            canvas.lineTo(darkBaseWidth, pageHeight - 50);
            canvas.curveTo(darkBaseWidth + 30, pageHeight - 50,
                          darkPointX - 20, arrowMiddleY + 80,
                          darkPointX, arrowMiddleY);
            canvas.curveTo(darkPointX - 20, arrowMiddleY - 80,
                          darkBaseWidth + 30, 50,
                          darkBaseWidth, 50);
            canvas.lineTo(0, 50);
            canvas.closePath();
            canvas.fill();

            float blueBaseWidth = 110;
            float bluePointX = 190;

            canvas.setFillColor(blueColor);
            canvas.moveTo(0, pageHeight - 70);
            canvas.lineTo(blueBaseWidth, pageHeight - 70);
            canvas.curveTo(blueBaseWidth + 25, pageHeight - 70,
                          bluePointX - 15, arrowMiddleY + 60,
                          bluePointX, arrowMiddleY);
            canvas.curveTo(bluePointX - 15, arrowMiddleY - 60,
                          blueBaseWidth + 25, 70,
                          blueBaseWidth, 70);
            canvas.lineTo(0, 70);
            canvas.closePath();
            canvas.fill();

            float contentStartX = darkPointX + 30;
            float contentWidth = pageWidth - contentStartX - 60;
            float contentCenterX = contentStartX + (contentWidth / 2);

            canvas.beginText();
            canvas.setFontAndSize(italicFont, 48);
            canvas.setFillColor(blueColor);
            String title1 = "Certificate";
            float title1Width = italicFont.getWidth(title1, 48);
            canvas.moveText(contentStartX + (contentWidth - title1Width) / 2, pageHeight - 100);
            canvas.showText(title1);
            canvas.endText();

            canvas.beginText();
            canvas.setFontAndSize(italicFont, 48);
            canvas.setFillColor(blueColor);
            String title2 = "Of Attendance";
            float title2Width = italicFont.getWidth(title2, 48);
            canvas.moveText(contentStartX + (contentWidth - title2Width) / 2, pageHeight - 155);
            canvas.showText(title2);
            canvas.endText();

            canvas.beginText();
            canvas.setFontAndSize(regularFont, 14);
            canvas.setFillColor(grayColor);
            String certifyText = "This is to certify that";
            float certifyWidth = regularFont.getWidth(certifyText, 14);
            canvas.moveText(contentStartX + (contentWidth - certifyWidth) / 2, pageHeight - 210);
            canvas.showText(certifyText);
            canvas.endText();

            canvas.beginText();
            canvas.setFontAndSize(italicFont, 42);
            canvas.setFillColor(blueColor);
            String userName = user.getFullName();
            float nameWidth = italicFont.getWidth(userName, 42);
            canvas.moveText(contentStartX + (contentWidth - nameWidth) / 2, pageHeight - 265);
            canvas.showText(userName);
            canvas.endText();

            String eventDate = event.getStartTime().format(DateTimeFormatter.ofPattern("MMMM d, yyyy"));
            String eventDesc = "attended the \"" + event.getTitle() + "\"";

            canvas.beginText();
            canvas.setFontAndSize(regularFont, 13);
            canvas.setFillColor(grayColor);
            float descWidth = regularFont.getWidth(eventDesc, 13);
            canvas.moveText(contentStartX + (contentWidth - descWidth) / 2, pageHeight - 310);
            canvas.showText(eventDesc);
            canvas.endText();

            String conductedText = "conducted on " + eventDate + ".";
            canvas.beginText();
            canvas.setFontAndSize(regularFont, 13);
            canvas.setFillColor(grayColor);
            float conductedWidth = regularFont.getWidth(conductedText, 13);
            canvas.moveText(contentStartX + (contentWidth - conductedWidth) / 2, pageHeight - 330);
            canvas.showText(conductedText);
            canvas.endText();

            String presentedDate = event.getEndTime().format(DateTimeFormatter.ofPattern("MMMM d, yyyy"));
            String presentedText = "Presented on " + presentedDate + ".";
            canvas.beginText();
            canvas.setFontAndSize(regularFont, 13);
            canvas.setFillColor(grayColor);
            float presentedWidth = regularFont.getWidth(presentedText, 13);
            canvas.moveText(contentStartX + (contentWidth - presentedWidth) / 2, pageHeight - 380);
            canvas.showText(presentedText);
            canvas.endText();

            float lineY = pageHeight - 430;
            float lineStartX = contentStartX + (contentWidth / 2) - 80;
            float lineEndX = contentStartX + (contentWidth / 2) + 80;

            canvas.setStrokeColor(blueColor);
            canvas.setLineWidth(1);
            canvas.setLineDash(5, 3);
            canvas.moveTo(lineStartX, lineY);
            canvas.lineTo(lineEndX, lineY);
            canvas.stroke();

            canvas.beginText();
            canvas.setFontAndSize(regularFont, 12);
            canvas.setFillColor(blueColor);
            String coordText = "Event Co-ordinator";
            float coordWidth = regularFont.getWidth(coordText, 12);
            canvas.moveText(contentStartX + (contentWidth - coordWidth) / 2, lineY - 20);
            canvas.showText(coordText);
            canvas.endText();

            document.close();
            return baos.toByteArray();

        } catch (IOException e) {
            log.error("Failed to generate certificate PDF", e);
            throw new RuntimeException("Failed to generate certificate PDF", e);
        }
    }

    private byte[] generateQRCode(String content) {
        try {
            QRCodeWriter qrCodeWriter = new QRCodeWriter();
            BitMatrix bitMatrix = qrCodeWriter.encode(content, BarcodeFormat.QR_CODE, 200, 200);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            MatrixToImageWriter.writeToStream(bitMatrix, "PNG", baos);
            return baos.toByteArray();

        } catch (WriterException | IOException e) {
            log.error("Failed to generate QR code", e);
            throw new RuntimeException("Failed to generate QR code", e);
        }
    }

    private String uploadPdfToCloudinary(byte[] pdfBytes, String certificateCode) {
        try {
            Map<String, Object> options = ObjectUtils.asMap(
                    "folder", "luma/certificates",
                    "public_id", certificateCode,
                    "resource_type", "raw"
            );

            Map<?, ?> result = cloudinary.uploader().upload(pdfBytes, options);
            String secureUrl = (String) result.get("secure_url");
            log.info("Certificate PDF uploaded to Cloudinary: {}", secureUrl);
            return secureUrl;

        } catch (IOException e) {
            log.error("Failed to upload certificate to Cloudinary", e);
            throw new RuntimeException("Failed to upload certificate", e);
        }
    }

    private byte[] downloadImage(String imageUrl) {
        try {
            URL url = new URL(imageUrl);
            try (InputStream is = url.openStream();
                 ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[4096];
                int bytesRead;
                while ((bytesRead = is.read(buffer)) != -1) {
                    baos.write(buffer, 0, bytesRead);
                }
                return baos.toByteArray();
            }
        } catch (IOException e) {
            log.warn("Failed to download image from {}: {}", imageUrl, e.getMessage());
            return null;
        }
    }
}
