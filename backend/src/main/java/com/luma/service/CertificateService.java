package com.luma.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.MultiFormatWriter;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.itextpdf.io.font.PdfEncodings;
import com.itextpdf.io.font.constants.StandardFonts;
import com.itextpdf.io.image.ImageData;
import com.itextpdf.io.image.ImageDataFactory;
import com.itextpdf.kernel.colors.DeviceRgb;
import com.itextpdf.kernel.font.PdfFont;
import com.itextpdf.kernel.font.PdfFontFactory;
import com.itextpdf.kernel.geom.PageSize;
import com.itextpdf.kernel.geom.Rectangle;
import com.itextpdf.kernel.pdf.PdfDocument;
import com.itextpdf.kernel.pdf.PdfPage;
import com.itextpdf.kernel.pdf.PdfWriter;
import com.itextpdf.kernel.pdf.canvas.PdfCanvas;
import com.itextpdf.kernel.pdf.extgstate.PdfExtGState;
import com.itextpdf.layout.Document;
import com.itextpdf.layout.element.Image;
import com.itextpdf.layout.element.Paragraph;
import com.itextpdf.layout.element.Text;
import com.itextpdf.layout.properties.TextAlignment;
import com.luma.dto.response.CertificateResponse;
import com.luma.dto.response.PageResponse;
import com.luma.entity.Certificate;
import com.luma.entity.Event;
import com.luma.entity.OrganiserProfile;
import com.luma.entity.Registration;
import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.exception.ResourceNotFoundException;
import com.luma.repository.CertificateRepository;
import com.luma.repository.RegistrationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLConnection;
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
    private final EmailService emailService;

    @Value("${app.base-url:http://localhost:8080}")
    private String baseUrl;

    private static final String CERTIFICATE_CODE_PREFIX = "CERT-";

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
        LocalDateTime generatedAt = LocalDateTime.now();

        byte[] pdfBytes = generateCertificatePdf(registration, certificateCode, generatedAt);

        String certificateUrl = uploadPdfToCloudinary(pdfBytes, certificateCode);

        Certificate certificate = Certificate.builder()
                .registration(registration)
                .certificateCode(certificateCode)
                .certificateUrl(certificateUrl)
                .generatedAt(generatedAt)
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

    @Transactional(readOnly = true)
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

    @Transactional(readOnly = true)
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

    @Transactional(readOnly = true)
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

    @Transactional(readOnly = true)
    public CertificateResponse verifyCertificate(String code) {
        Certificate certificate = certificateRepository.findByCertificateCode(code)
                .orElseThrow(() -> new ResourceNotFoundException("Certificate not found or invalid"));

        return CertificateResponse.fromEntity(certificate);
    }

    @Transactional(readOnly = true)
    public byte[] downloadCertificate(UUID certificateId, User user) {
        Certificate certificate = certificateRepository.findById(certificateId)
                .orElseThrow(() -> new ResourceNotFoundException("Certificate not found"));

        if (!certificate.getRegistration().getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only download your own certificates");
        }

        return generateCertificatePdf(
                certificate.getRegistration(),
                certificate.getCertificateCode(),
                certificate.getGeneratedAt()
        );
    }

    @Transactional(readOnly = true)
    public byte[] getCertificatePdfByCode(String code) {
        Certificate certificate = certificateRepository.findByCertificateCode(code)
                .orElseThrow(() -> new ResourceNotFoundException("Certificate not found"));

        return generateCertificatePdf(
                certificate.getRegistration(),
                certificate.getCertificateCode(),
                certificate.getGeneratedAt()
        );
    }

    @Transactional
    public CertificateResponse sendCertificateByEmail(UUID registrationId, User user) {
        Registration registration = registrationRepository.findById(registrationId)
                .orElseThrow(() -> new ResourceNotFoundException("Registration not found"));

        if (!registration.getUser().getId().equals(user.getId())) {
            throw new BadRequestException("You can only request certificates for your own registrations");
        }

        validateCertificateEligibility(registration);

        Certificate certificate = certificateRepository.findByRegistration(registration)
                .orElseGet(() -> {
                    CertificateResponse response = generateCertificate(registrationId);
                    return certificateRepository.findById(response.getId()).orElseThrow();
                });

        Event event = registration.getEvent();
        User attendee = registration.getUser();

        emailService.sendCertificateEmail(
                attendee.getEmail(),
                attendee.getFullName(),
                event.getTitle(),
                event.getStartTime(),
                event.getOrganiser().getFullName(),
                event.getVenue(),
                certificate.getCertificateCode(),
                certificate.getCertificateUrl()
        );

        log.info("Certificate email sent to {} for event {}", attendee.getEmail(), event.getTitle());

        return CertificateResponse.fromEntity(certificate);
    }

    @Transactional(readOnly = true)
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

    private byte[] generateCertificatePdf(
            Registration registration,
            String certificateCode,
            LocalDateTime issuedAt
    ) {
        Event event = registration.getEvent();
        User attendee = registration.getUser();
        User organiser = event.getOrganiser();
        OrganiserProfile organiserProfile = organiser.getOrganiserProfile();

        String organiserName = resolveOrganiserName(organiser, organiserProfile);
        String location = firstNonBlank(event.getVenue(), event.getAddress(), "Location to be announced");
        String eventDate = formatDate(event.getStartTime());
        String issuedDate = formatDate(issuedAt != null ? issuedAt : LocalDateTime.now());
        String officialCopyUrl = buildPublicCertificateUrl(certificateCode);

        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            PdfWriter writer = new PdfWriter(baos);
            PdfDocument pdf = new PdfDocument(writer);
            PdfPage page = pdf.addNewPage(PageSize.A4.rotate());
            Document document = new Document(pdf, PageSize.A4.rotate());
            document.setMargins(0, 0, 0, 0);

            DeviceRgb paperColor = new DeviceRgb(249, 246, 238);
            DeviceRgb panelColor = new DeviceRgb(255, 252, 247);
            DeviceRgb navyColor = new DeviceRgb(20, 38, 68);
            DeviceRgb slateColor = new DeviceRgb(92, 102, 118);
            DeviceRgb goldColor = new DeviceRgb(192, 156, 85);
            DeviceRgb lineColor = new DeviceRgb(222, 212, 191);
            DeviceRgb mistBlueColor = new DeviceRgb(228, 236, 247);

            PdfFont bodyFont = loadFont("fonts/arial.ttf", StandardFonts.HELVETICA);
            PdfFont bodyBoldFont = loadFont("fonts/arialbd.ttf", StandardFonts.HELVETICA_BOLD);
            PdfFont bodyItalicFont = loadFont("fonts/ariali.ttf", StandardFonts.HELVETICA_OBLIQUE);
            PdfFont serifBoldFont = loadFont("fonts/georgiab.ttf", StandardFonts.TIMES_BOLD);

            Rectangle pageSize = page.getPageSize();
            float pageWidth = pageSize.getWidth();
            float pageHeight = pageSize.getHeight();
            PdfCanvas canvas = new PdfCanvas(page);

            drawCertificateBackground(
                    canvas,
                    pageWidth,
                    pageHeight,
                    paperColor,
                    navyColor,
                    goldColor,
                    mistBlueColor
            );

            drawHeaderBand(
                    canvas,
                    document,
                    pageWidth,
                    pageHeight,
                    navyColor,
                    goldColor,
                    panelColor,
                    bodyBoldFont,
                    bodyFont,
                    certificateCode,
                    issuedDate
            );

            addTextBlock(
                    document,
                    new Paragraph("CERTIFICATE OF ATTENDANCE")
                            .setFont(bodyBoldFont)
                            .setFontSize(10)
                            .setFontColor(goldColor)
                            .setCharacterSpacing(1.8f)
                            .setTextAlignment(TextAlignment.CENTER),
                    150,
                    pageHeight - 168,
                    pageWidth - 300
            );

            addTextBlock(
                    document,
                    new Paragraph("Certificate of Attendance")
                            .setFont(serifBoldFont)
                            .setFontSize(30)
                            .setFontColor(navyColor)
                            .setTextAlignment(TextAlignment.CENTER),
                    104,
                    pageHeight - 214,
                    pageWidth - 208
            );

            canvas.saveState()
                    .setFillColor(goldColor)
                    .roundRectangle((pageWidth / 2) - 42, pageHeight - 228, 84, 3, 2)
                    .fill()
                    .restoreState();

            addTextBlock(
                    document,
                    new Paragraph("This certificate is proudly presented to")
                            .setFont(bodyFont)
                            .setFontSize(13)
                            .setFontColor(slateColor)
                            .setTextAlignment(TextAlignment.CENTER),
                    150,
                    pageHeight - 266,
                    pageWidth - 300
            );

            addTextBlock(
                    document,
                    new Paragraph(defaultString(attendee.getFullName(), "Attendee"))
                            .setFont(bodyBoldFont)
                            .setFontSize(25)
                            .setFontColor(navyColor)
                            .setTextAlignment(TextAlignment.CENTER),
                    116,
                    pageHeight - 322,
                    pageWidth - 232
            );

            Paragraph narrative = new Paragraph()
                    .add(new Text("for attending ").setFont(bodyFont))
                    .add(new Text('"' + defaultString(event.getTitle(), "Untitled Event") + '"')
                            .setFont(bodyBoldFont)
                            .setFontColor(navyColor))
                    .add(new Text(" hosted by ").setFont(bodyFont))
                    .add(new Text(organiserName).setFont(bodyBoldFont).setFontColor(navyColor))
                    .add(new Text(".").setFont(bodyFont))
                    .setFontSize(12.5f)
                    .setFontColor(slateColor)
                    .setMultipliedLeading(1.25f)
                    .setTextAlignment(TextAlignment.CENTER);
            addTextBlock(document, narrative, 94, pageHeight - 352, pageWidth - 188);

            drawSeal(canvas, document, pageWidth - 132, pageHeight - 290, goldColor, panelColor, navyColor, bodyBoldFont);

            float panelsY = 70;
            float panelHeight = 150;

            drawPanel(canvas, 56, panelsY, 340, panelHeight, panelColor, lineColor);
            drawPanel(canvas, 414, panelsY, 200, panelHeight, panelColor, lineColor);
            drawPanel(canvas, 632, panelsY, 154, panelHeight, panelColor, lineColor);

            addTextBlock(
                    document,
                    new Paragraph("EVENT DETAILS")
                            .setFont(bodyBoldFont)
                            .setFontSize(9)
                            .setFontColor(goldColor)
                            .setCharacterSpacing(1.4f),
                    78,
                    panelsY + 122,
                    170
            );
            addTextBlock(
                    document,
                    new Paragraph(defaultString(event.getTitle(), "Untitled Event"))
                            .setFont(bodyBoldFont)
                            .setFontSize(14)
                            .setFontColor(navyColor)
                            .setMultipliedLeading(1.15f),
                    78,
                    panelsY + 82,
                    296
            );
            addKeyValueBlock(document, "Organiser", organiserName, 78, panelsY + 46, 296, bodyBoldFont, bodyFont, slateColor, navyColor);
            addKeyValueBlock(document, "Event date", eventDate, 78, panelsY + 24, 140, bodyBoldFont, bodyFont, slateColor, navyColor);
            addKeyValueBlock(document, "Location", location, 228, panelsY + 24, 146, bodyBoldFont, bodyFont, slateColor, navyColor);

            addTextBlock(
                    document,
                    new Paragraph("ISSUED BY")
                            .setFont(bodyBoldFont)
                            .setFontSize(9)
                            .setFontColor(goldColor)
                            .setCharacterSpacing(1.4f)
                            .setTextAlignment(TextAlignment.CENTER),
                    432,
                    panelsY + 122,
                    164
            );
            addSignatureSection(
                    canvas,
                    document,
                    414,
                    panelsY,
                    200,
                    organiserName,
                    organiserProfile != null && organiserProfile.isVerified()
                            ? "Verified organiser on LUMA"
                            : "Event organiser",
                    organiser.getSignatureUrl(),
                    bodyBoldFont,
                    bodyFont,
                    bodyItalicFont,
                    navyColor,
                    slateColor
            );

            addTextBlock(
                    document,
                    new Paragraph("OFFICIAL COPY")
                            .setFont(bodyBoldFont)
                            .setFontSize(9)
                            .setFontColor(goldColor)
                            .setCharacterSpacing(1.4f)
                            .setTextAlignment(TextAlignment.CENTER),
                    644,
                    panelsY + 122,
                    130
            );
            addQrPanel(
                    document,
                    632,
                    panelsY,
                    154,
                    officialCopyUrl,
                    certificateCode,
                    bodyBoldFont,
                    bodyFont,
                    navyColor,
                    slateColor
            );

            document.close();
            return baos.toByteArray();
        } catch (IOException e) {
            log.error("Failed to generate certificate PDF", e);
            throw new RuntimeException("Failed to generate certificate PDF", e);
        }
    }

    private void drawCertificateBackground(
            PdfCanvas canvas,
            float pageWidth,
            float pageHeight,
            DeviceRgb paperColor,
            DeviceRgb navyColor,
            DeviceRgb goldColor,
            DeviceRgb mistBlueColor
    ) {
        canvas.saveState()
                .setFillColor(paperColor)
                .rectangle(0, 0, pageWidth, pageHeight)
                .fill()
                .restoreState();

        PdfExtGState softTint = new PdfExtGState().setFillOpacity(0.18f);
        canvas.saveState()
                .setExtGState(softTint)
                .setFillColor(mistBlueColor)
                .circle(96, pageHeight - 24, 122)
                .fill()
                .restoreState();
        canvas.saveState()
                .setExtGState(softTint)
                .setFillColor(goldColor)
                .circle(pageWidth - 12, 48, 118)
                .fill()
                .restoreState();

        canvas.saveState()
                .setStrokeColor(navyColor)
                .setLineWidth(3)
                .roundRectangle(20, 20, pageWidth - 40, pageHeight - 40, 24)
                .stroke()
                .restoreState();
        canvas.saveState()
                .setStrokeColor(goldColor)
                .setLineWidth(1.4f)
                .roundRectangle(32, 32, pageWidth - 64, pageHeight - 64, 20)
                .stroke()
                .restoreState();
    }

    private void drawHeaderBand(
            PdfCanvas canvas,
            Document document,
            float pageWidth,
            float pageHeight,
            DeviceRgb navyColor,
            DeviceRgb goldColor,
            DeviceRgb panelColor,
            PdfFont bodyBoldFont,
            PdfFont bodyFont,
            String certificateCode,
            String issuedDate
    ) throws IOException {
        float bandX = 46;
        float bandY = pageHeight - 108;
        float bandWidth = pageWidth - 92;
        float bandHeight = 74;

        canvas.saveState()
                .setFillColor(navyColor)
                .roundRectangle(bandX, bandY, bandWidth, bandHeight, 18)
                .fill()
                .restoreState();
        canvas.saveState()
                .setFillColor(goldColor)
                .roundRectangle(bandX, bandY - 4, bandWidth, 4, 2)
                .fill()
                .restoreState();

        float logoCardX = bandX + 18;
        float logoCardY = bandY + 9;
        float logoCardSize = 56;
        canvas.saveState()
                .setFillColor(panelColor)
                .roundRectangle(logoCardX, logoCardY, logoCardSize, logoCardSize, 14)
                .fill()
                .restoreState();

        ImageData logoImageData = loadPlatformLogo();
        if (logoImageData != null) {
            Image logoImage = new Image(logoImageData);
            logoImage.scaleToFit(44, 44);
            logoImage.setFixedPosition(
                    logoCardX + (logoCardSize - logoImage.getImageScaledWidth()) / 2,
                    logoCardY + (logoCardSize - logoImage.getImageScaledHeight()) / 2
            );
            document.add(logoImage);
        } else {
            addTextBlock(
                    document,
                    new Paragraph("L")
                            .setFont(bodyBoldFont)
                            .setFontSize(24)
                            .setFontColor(navyColor)
                            .setTextAlignment(TextAlignment.CENTER),
                    logoCardX,
                    logoCardY + 14,
                    logoCardSize
            );
        }

        addTextBlock(
                document,
                new Paragraph("LUMA")
                        .setFont(bodyBoldFont)
                        .setFontSize(16)
                        .setFontColor(panelColor),
                bandX + 92,
                bandY + 38,
                120
        );
        addTextBlock(
                document,
                new Paragraph("Official event participation credential")
                        .setFont(bodyFont)
                        .setFontSize(10.5f)
                        .setFontColor(panelColor),
                bandX + 92,
                bandY + 18,
                240
        );

        float pillWidth = 178;
        float pillHeight = 28;
        float pillX = pageWidth - 230;
        float pillY = bandY + 34;
        canvas.saveState()
                .setFillColor(panelColor)
                .roundRectangle(pillX, pillY, pillWidth, pillHeight, 14)
                .fill()
                .restoreState();
        addTextBlock(
                document,
                new Paragraph(certificateCode)
                        .setFont(bodyBoldFont)
                        .setFontSize(10)
                        .setFontColor(navyColor)
                        .setTextAlignment(TextAlignment.CENTER),
                pillX,
                pillY + 8,
                pillWidth
        );
        addTextBlock(
                document,
                new Paragraph("Issued " + issuedDate)
                        .setFont(bodyFont)
                        .setFontSize(10)
                        .setFontColor(panelColor)
                        .setTextAlignment(TextAlignment.RIGHT),
                pageWidth - 250,
                bandY + 12,
                198
        );
    }

    private void drawPanel(
            PdfCanvas canvas,
            float x,
            float y,
            float width,
            float height,
            DeviceRgb fillColor,
            DeviceRgb strokeColor
    ) {
        canvas.saveState()
                .setFillColor(fillColor)
                .roundRectangle(x, y, width, height, 18)
                .fill()
                .restoreState();
        canvas.saveState()
                .setStrokeColor(strokeColor)
                .setLineWidth(1)
                .roundRectangle(x, y, width, height, 18)
                .stroke()
                .restoreState();
    }

    private void drawSeal(
            PdfCanvas canvas,
            Document document,
            float centerX,
            float centerY,
            DeviceRgb goldColor,
            DeviceRgb panelColor,
            DeviceRgb navyColor,
            PdfFont bodyBoldFont
    ) {
        canvas.saveState()
                .setFillColor(panelColor)
                .circle(centerX, centerY, 42)
                .fill()
                .restoreState();
        canvas.saveState()
                .setStrokeColor(goldColor)
                .setLineWidth(2.2f)
                .circle(centerX, centerY, 42)
                .stroke()
                .circle(centerX, centerY, 34)
                .stroke()
                .restoreState();

        addTextBlock(
                document,
                new Paragraph("LUMA")
                        .setFont(bodyBoldFont)
                        .setFontSize(8)
                        .setFontColor(goldColor)
                        .setTextAlignment(TextAlignment.CENTER),
                centerX - 32,
                centerY + 10,
                64
        );
        addTextBlock(
                document,
                new Paragraph("CERTIFIED")
                        .setFont(bodyBoldFont)
                        .setFontSize(9)
                        .setFontColor(navyColor)
                        .setTextAlignment(TextAlignment.CENTER),
                centerX - 34,
                centerY - 4,
                68
        );
        addTextBlock(
                document,
                new Paragraph(String.valueOf(LocalDateTime.now().getYear()))
                        .setFont(bodyBoldFont)
                        .setFontSize(8)
                        .setFontColor(goldColor)
                        .setTextAlignment(TextAlignment.CENTER),
                centerX - 24,
                centerY - 20,
                48
        );
    }

    private void addSignatureSection(
            PdfCanvas canvas,
            Document document,
            float panelX,
            float panelY,
            float panelWidth,
            String organiserName,
            String subtitle,
            String signatureUrl,
            PdfFont bodyBoldFont,
            PdfFont bodyFont,
            PdfFont fallbackSignatureFont,
            DeviceRgb navyColor,
            DeviceRgb slateColor
    ) throws IOException {
        ImageData signatureImageData = tryLoadRemoteImage(signatureUrl);

        if (signatureImageData != null) {
            Image signatureImage = new Image(signatureImageData);
            signatureImage.scaleToFit(120, 42);
            signatureImage.setFixedPosition(
                    panelX + (panelWidth - signatureImage.getImageScaledWidth()) / 2,
                    panelY + 70
            );
            document.add(signatureImage);
        } else {
            addTextBlock(
                    document,
                    new Paragraph(organiserName)
                            .setFont(fallbackSignatureFont)
                            .setFontSize(22)
                            .setFontColor(navyColor)
                            .setTextAlignment(TextAlignment.CENTER),
                    panelX + 20,
                    panelY + 76,
                    panelWidth - 40
            );
        }

        canvas.saveState()
                .setStrokeColor(navyColor)
                .setLineWidth(1)
                .moveTo(panelX + 28, panelY + 62)
                .lineTo(panelX + panelWidth - 28, panelY + 62)
                .stroke()
                .restoreState();

        addTextBlock(
                document,
                new Paragraph(organiserName)
                        .setFont(bodyBoldFont)
                        .setFontSize(11)
                        .setFontColor(navyColor)
                        .setTextAlignment(TextAlignment.CENTER),
                panelX + 22,
                panelY + 34,
                panelWidth - 44
        );
        addTextBlock(
                document,
                new Paragraph(subtitle)
                        .setFont(bodyFont)
                        .setFontSize(9.5f)
                        .setFontColor(slateColor)
                        .setTextAlignment(TextAlignment.CENTER),
                panelX + 18,
                panelY + 18,
                panelWidth - 36
        );
    }

    private void addQrPanel(
            Document document,
            float panelX,
            float panelY,
            float panelWidth,
            String qrContent,
            String certificateCode,
            PdfFont bodyBoldFont,
            PdfFont bodyFont,
            DeviceRgb navyColor,
            DeviceRgb slateColor
    ) throws IOException {
        ImageData qrImageData = createQrCodeImage(qrContent, 180);
        Image qrImage = new Image(qrImageData);
        qrImage.scaleToFit(86, 86);
        qrImage.setFixedPosition(
                panelX + (panelWidth - qrImage.getImageScaledWidth()) / 2,
                panelY + 46
        );
        document.add(qrImage);

        addTextBlock(
                document,
                new Paragraph("Scan to open the official copy")
                        .setFont(bodyFont)
                        .setFontSize(8.8f)
                        .setFontColor(slateColor)
                        .setTextAlignment(TextAlignment.CENTER),
                panelX + 10,
                panelY + 24,
                panelWidth - 20
        );
        addTextBlock(
                document,
                new Paragraph(certificateCode)
                        .setFont(bodyBoldFont)
                        .setFontSize(8.8f)
                        .setFontColor(navyColor)
                        .setTextAlignment(TextAlignment.CENTER),
                panelX + 8,
                panelY + 10,
                panelWidth - 16
        );
    }

    private void addKeyValueBlock(
            Document document,
            String label,
            String value,
            float x,
            float y,
            float width,
            PdfFont labelFont,
            PdfFont valueFont,
            DeviceRgb labelColor,
            DeviceRgb valueColor
    ) {
        Paragraph paragraph = new Paragraph()
                .add(new Text(label + "\n")
                        .setFont(labelFont)
                        .setFontSize(8.5f)
                        .setFontColor(labelColor))
                .add(new Text(defaultString(value, "-"))
                        .setFont(valueFont)
                        .setFontSize(10.5f)
                        .setFontColor(valueColor))
                .setMultipliedLeading(1.1f);

        addTextBlock(document, paragraph, x, y, width);
    }

    private void addTextBlock(
            Document document,
            Paragraph paragraph,
            float x,
            float y,
            float width
    ) {
        paragraph.setMargin(0);
        paragraph.setFixedPosition(x, y, width);
        document.add(paragraph);
    }

    private PdfFont loadFont(String classpathLocation, String fallbackFont) throws IOException {
        try (InputStream inputStream = new ClassPathResource(classpathLocation).getInputStream()) {
            return PdfFontFactory.createFont(inputStream.readAllBytes(), PdfEncodings.IDENTITY_H);
        } catch (Exception e) {
            log.warn("Falling back to standard font {} because {} could not be loaded: {}",
                    fallbackFont, classpathLocation, e.getMessage());
            return PdfFontFactory.createFont(fallbackFont);
        }
    }

    private ImageData loadPlatformLogo() {
        try (InputStream inputStream = new ClassPathResource("static/luma-logo.png").getInputStream()) {
            return ImageDataFactory.create(inputStream.readAllBytes());
        } catch (Exception e) {
            log.debug("Could not load platform logo from classpath: {}", e.getMessage());
            return null;
        }
    }

    private ImageData tryLoadRemoteImage(String imageUrl) {
        if (imageUrl == null || imageUrl.isBlank()) {
            return null;
        }

        try {
            URLConnection connection = new URL(imageUrl).openConnection();
            connection.setConnectTimeout(3000);
            connection.setReadTimeout(4000);
            try (InputStream inputStream = connection.getInputStream()) {
                return ImageDataFactory.create(inputStream.readAllBytes());
            }
        } catch (Exception e) {
            log.debug("Could not load certificate image from {}: {}", imageUrl, e.getMessage());
            return null;
        }
    }

    private ImageData createQrCodeImage(String content, int size) throws IOException {
        try (ByteArrayOutputStream qrOut = new ByteArrayOutputStream()) {
            BitMatrix matrix = new MultiFormatWriter()
                    .encode(content, BarcodeFormat.QR_CODE, size, size);
            MatrixToImageWriter.writeToStream(matrix, "PNG", qrOut);
            return ImageDataFactory.create(qrOut.toByteArray());
        } catch (Exception e) {
            throw new IOException("Failed to generate certificate QR code", e);
        }
    }

    private String buildPublicCertificateUrl(String certificateCode) {
        String normalizedBaseUrl = baseUrl.endsWith("/")
                ? baseUrl.substring(0, baseUrl.length() - 1)
                : baseUrl;
        return normalizedBaseUrl + "/api/certificates/" + certificateCode + "/pdf?download=false";
    }

    private String resolveOrganiserName(User organiser, OrganiserProfile organiserProfile) {
        if (organiserProfile != null && organiserProfile.getDisplayName() != null
                && !organiserProfile.getDisplayName().isBlank()) {
            return organiserProfile.getDisplayName();
        }
        return defaultString(organiser.getFullName(), "LUMA Organiser");
    }

    private String resolveOrganiserLogoUrl(User organiser, OrganiserProfile organiserProfile) {
        if (organiserProfile != null && organiserProfile.getLogoUrl() != null
                && !organiserProfile.getLogoUrl().isBlank()) {
            return organiserProfile.getLogoUrl();
        }
        return organiser.getAvatarUrl();
    }

    private String formatDate(LocalDateTime dateTime) {
        return dateTime.format(DateTimeFormatter.ofPattern("MMMM d, yyyy"));
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return "";
    }

    private String defaultString(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

    private String uploadPdfToCloudinary(byte[] pdfBytes, String certificateCode) {
        try {
            Map<String, Object> options = ObjectUtils.asMap(
                    "folder", "luma/certificates",
                    "public_id", certificateCode,
                    "resource_type", "image",
                    "format", "pdf",
                    "use_filename", false,
                    "unique_filename", false
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

}
