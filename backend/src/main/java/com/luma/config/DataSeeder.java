package com.luma.config;

import com.luma.entity.*;
import com.luma.entity.enums.*;
import com.luma.repository.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final OrganiserProfileRepository organiserProfileRepository;
    private final CategoryRepository categoryRepository;
    private final CityRepository cityRepository;
    private final EventRepository eventRepository;
    private final TicketTypeRepository ticketTypeRepository;
    private final RegistrationRepository registrationRepository;
    private final CertificateRepository certificateRepository;
    private final SpeakerRepository speakerRepository;
    private final ReviewRepository reviewRepository;
    private final FollowRepository followRepository;
    private final ConnectionRequestRepository connectionRequestRepository;
    private final BookmarkRepository bookmarkRepository;
    private final PasswordEncoder passwordEncoder;

    @PersistenceContext
    private EntityManager entityManager;

    private final Random random = new Random(42);

    // Image URLs from Unsplash for professional look
    private static final String[] AVATAR_URLS = {
        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1488161628813-99c974c76949?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1520813792240-56fc4a37b1a9?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=200&h=200&fit=crop&crop=face",
        "https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=200&h=200&fit=crop&crop=face"
    };

    private static final String[] EVENT_IMAGE_URLS = {
        "https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1511578314322-379afb476865?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1528605248644-14dd04022da1?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1561489413-985b06da5bee?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1515187029135-18ee4f6d0b7e?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1598550476439-6847785fcea6?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1544531586-fde5298cdd40?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1510525009512-ad7fc13eefab?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1551818255-e6e10975bc17?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1523580494863-6f3031224c94?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1504450874802-0ed2a274c193?w=800&h=400&fit=crop",
        "https://images.unsplash.com/photo-1533174072545-e8d4aa97edf9?w=800&h=400&fit=crop"
    };

    private static final String[] ORGANISER_LOGO_URLS = {
        "https://images.unsplash.com/photo-1560179707-f14e90ef362b?w=200&h=200&fit=crop",
        "https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=200&h=200&fit=crop",
        "https://images.unsplash.com/photo-1497366216548-37526070297c?w=200&h=200&fit=crop",
        "https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=200&h=200&fit=crop",
        "https://images.unsplash.com/photo-1556740738-b6a63e27c4df?w=200&h=200&fit=crop",
        "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=200&h=200&fit=crop",
        "https://images.unsplash.com/photo-1552664730-d307ca884978?w=200&h=200&fit=crop",
        "https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=200&h=200&fit=crop"
    };

    @Override
    @Transactional
    public void run(String... args) {
        // Check if already seeded (check for admin user)
        boolean alreadySeeded = userRepository.findByEmail("admin@luma.com").isPresent();

        if (alreadySeeded) {
            log.info("=== Database already seeded. Skipping initial data... ===");
            // Ensure reference data exists (idempotent) — cities may be empty after manual cleanup
            if (cityRepository.count() == 0) {
                log.info("=== Cities table empty — re-seeding cities... ===");
                seedCities();
            }
            // But still seed registration questions for events that need them
            log.info("=== Checking for missing registration questions... ===");
            seedRegistrationQuestions();
            // Fix ticket types for free events
            log.info("=== Checking for free events with incorrect ticket types... ===");
            fixFreeEventTicketTypes();
            log.info("=== Data seeding check completed ===");
            return;
        }

        log.info("=== Starting initial data seeding... ===");

        migrateNullColumns();

        seedCategories();
        seedCities();
        seedRegularUsers();
        seedOrganiserUsers();
        seedAdminUser();
        seedEvents();
        seedRegistrationQuestions();
        seedTicketTypes();
        seedSpeakers();
        seedRegistrations();
        seedCertificates();
        seedReviews();
        seedFollows();
        seedConnections();
        seedBookmarks();

        log.info("=== Data seeding completed successfully ===");
    }

    private void migrateNullColumns() {
        try {
            int updated = entityManager.createNativeQuery(
                    "UPDATE users SET networking_visible = 1 WHERE networking_visible IS NULL"
            ).executeUpdate();
            if (updated > 0) {
                log.info("Migrated {} users with networking_visible default", updated);
            }
        } catch (Exception e) {
            log.warn("Could not run networking_visible migration: {}", e.getMessage());
        }
    }

    private void seedAdminUser() {
        if (!userRepository.existsByEmail("admin@luma.com")) {
            User admin = User.builder()
                    .email("admin@luma.com")
                    .password(passwordEncoder.encode("admin123"))
                    .fullName("LUMA Administrator")
                    .avatarUrl(AVATAR_URLS[0])
                    .role(UserRole.ADMIN)
                    .status(UserStatus.ACTIVE)
                    .emailVerified(true)
                    .build();
            userRepository.save(admin);
            log.info("✓ Created Admin: admin@luma.com / admin123");
        }
    }

    private void seedRegularUsers() {
        Object[][] users = {
            {"nguyenvan@gmail.com", "user123", "Nguyen Van A", "Software Engineer", "Tech enthusiast", "Ho Chi Minh", "0"},
            {"tranbi@gmail.com", "user123", "Tran Thi B", "Marketing Manager", "Digital marketing expert", "Ha Noi", "1"},
            {"leminh@gmail.com", "user123", "Le Minh C", "Product Designer", "UX/UI Designer", "Da Nang", "2"},
            {"phamduc@gmail.com", "user123", "Pham Duc D", "Data Scientist", "AI/ML researcher", "Ho Chi Minh", "3"},
            {"hoangmai@gmail.com", "user123", "Hoang Thi E", "Startup Founder", "Building the future", "Ha Noi", "4"},
            {"vuthanh@gmail.com", "user123", "Vu Thanh F", "DevOps Engineer", "Cloud infrastructure", "Ho Chi Minh", "5"},
            {"dangyen@gmail.com", "user123", "Dang Thi G", "Content Creator", "Social media influencer", "Da Nang", "6"},
            {"buihung@gmail.com", "user123", "Bui Van H", "Blockchain Dev", "Web3 builder", "Ho Chi Minh", "7"},
            {"ngoclan@gmail.com", "user123", "Ngoc Lan I", "HR Manager", "People operations", "Ha Noi", "8"},
            {"truongson@gmail.com", "user123", "Truong Son J", "Sales Director", "B2B sales expert", "Ho Chi Minh", "9"},
            {"lykha@gmail.com", "user123", "Ly Thi K", "Financial Analyst", "Investment banking", "Ha Noi", "10"},
            {"trungkiên@gmail.com", "user123", "Trung Kien L", "Mobile Developer", "iOS & Android apps", "Da Nang", "11"},
            {"quynhanh@gmail.com", "user123", "Quynh Thi M", "Event Planner", "Corporate events", "Ho Chi Minh", "12"},
            {"ducvuong@gmail.com", "user123", "Duc Vuong N", "Game Developer", "Unity & Unreal", "Ha Noi", "13"},
            {"minhkhu@gmail.com", "user123", "Minh Khu O", "Photographer", "Event & portrait", "Da Nang", "14"}
        };

        for (Object[] userData : users) {
            String email = (String) userData[0];
            if (!userRepository.existsByEmail(email)) {
                int avatarIndex = Integer.parseInt((String) userData[6]);
                User user = User.builder()
                        .email(email)
                        .password(passwordEncoder.encode((String) userData[1]))
                        .fullName((String) userData[2])
                        .jobTitle((String) userData[3])
                        .bio((String) userData[4])
                        .company("Vietnam Tech Co.")
                        .avatarUrl(AVATAR_URLS[avatarIndex % AVATAR_URLS.length])
                        .role(UserRole.USER)
                        .status(UserStatus.ACTIVE)
                        .emailVerified(true)
                        .phoneVerified(true)
                        .interests("Technology, Networking, Events")
                        .linkedinUrl("https://linkedin.com/in/" + email.split("@")[0])
                        .build();
                userRepository.save(user);
                log.info("✓ Created User: {} - {}", email, userData[2]);
            }
        }
    }

    private void seedOrganiserUsers() {
        Object[][] organisers = {
            {"techviet@luma.com", "techviet123", "TechViet Events", "TechViet", "Leading technology event organizer in Vietnam. We bring the best tech conferences and workshops to Vietnam.", "https://images.unsplash.com/photo-1560179707-f14e90ef362b?w=200&h=200&fit=crop", "technology", "0"},
            {"sunflower@luma.com", "sunflower123", "Sunflower Media", "Sunflower Media", "Specializing in music festivals, entertainment events, and cultural celebrations across Vietnam.", "https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=200&h=200&fit=crop", "entertainment", "1"},
            {"greenlife@luma.com", "greenlife123", "GreenLife Foundation", "GreenLife", "Non-profit organization dedicated to environment protection, health awareness, and sustainable living.", "https://images.unsplash.com/photo-1497366216548-37526070297c?w=200&h=200&fit=crop", "nonprofit", "2"},
            {"startupvn@luma.com", "startupvn123", "StartupVN Hub", "StartupVN", "Vietnam's premier startup community. Connecting entrepreneurs, investors, and innovators.", "https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=200&h=200&fit=crop", "startup", "3"},
            {"artspace@luma.com", "artspace123", "Art Space Gallery", "Art Space", "Contemporary art exhibitions, workshops, and cultural events in Ho Chi Minh City.", "https://images.unsplash.com/photo-1556740738-b6a63e27c4df?w=200&h=200&fit=crop", "arts", "4"},
            {"fitnesshub@luma.com", "fitness123", "Fitness Hub Vietnam", "Fitness Hub", "Health, fitness, and wellness events. Marathons, yoga retreats, and nutrition workshops.", "https://images.unsplash.com/photo-1552664730-d307ca884978?w=200&h=200&fit=crop", "fitness", "5"},
            {"food fest@luma.com", "foodfest123", "Food Festival VN", "Food Fest", "Celebrating Vietnamese and international cuisine. Food festivals and culinary workshops.", "https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=200&h=200&fit=crop", "food", "6"},
            {"eduvn@luma.com", "eduvn123", "EduVietnam", "EduVietnam", "Educational seminars, career fairs, and professional development workshops.", "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=200&h=200&fit=crop", "education", "7"}
        };

        for (Object[] orgData : organisers) {
            String email = (String) orgData[0];
            if (!userRepository.existsByEmail(email)) {
                User organiser = User.builder()
                        .email(email)
                        .password(passwordEncoder.encode((String) orgData[1]))
                        .fullName((String) orgData[2])
                        .avatarUrl((String) orgData[5])
                        .role(UserRole.ORGANISER)
                        .status(UserStatus.ACTIVE)
                        .emailVerified(true)
                        .bio((String) orgData[4])
                        .build();
                organiser = userRepository.save(organiser);

                OrganiserProfile profile = OrganiserProfile.builder()
                        .user(organiser)
                        .displayName((String) orgData[3])
                        .bio((String) orgData[4])
                        .logoUrl((String) orgData[5])
                        .contactEmail(email)
                        .website("https://www." + orgData[6] + ".com")
                        .verified(true)
                        .build();
                organiserProfileRepository.save(profile);
                log.info("✓ Created Organiser: {} - {}", email, orgData[2]);
            }
        }
    }

    private void seedCategories() {
        String[][] categories = {
            {"Technology", "#3B82F6"},
            {"AI & Machine Learning", "#8B5CF6"},
            {"Climate & Sustainability", "#10B981"},
            {"Sports & Fitness", "#F59E0B"},
            {"Business & Finance", "#6366F1"},
            {"Food & Beverage", "#EC4899"},
            {"Arts & Culture", "#EF4444"},
            {"Health & Wellness", "#14B8A6"},
            {"Music & Entertainment", "#F97316"},
            {"Education & Career", "#06B6D4"},
            {"Startup & Innovation", "#84CC16"},
            {"Photography", "#A855F7"}
        };

        for (String[] catData : categories) {
            if (!categoryRepository.existsByName(catData[0])) {
                Category category = Category.builder()
                        .name(catData[0])
                        .build();
                categoryRepository.save(category);
                log.info("✓ Created category: {}", catData[0]);
            }
        }
    }

    private void seedCities() {
        Object[][] cities = {
            {"Ho Chi Minh", "Asia", "Vietnam"},
            {"Ha Noi", "Asia", "Vietnam"},
            {"Da Nang", "Asia", "Vietnam"},
            {"Bangkok", "Asia", "Thailand"},
            {"Singapore", "Asia", "Singapore"},
            {"Tokyo", "Asia", "Japan"},
            {"Seoul", "Asia", "South Korea"},
            {"New York", "North America", "USA"},
            {"Los Angeles", "North America", "USA"},
            {"London", "Europe", "UK"},
            {"Paris", "Europe", "France"},
            {"Berlin", "Europe", "Germany"},
            {"Sydney", "Oceania", "Australia"}
        };

        for (Object[] cityData : cities) {
            String name = (String) cityData[0];
            String continent = (String) cityData[1];
            String country = (String) cityData[2];

            var existingCity = cityRepository.findByName(name);
            if (existingCity.isEmpty()) {
                City city = City.builder()
                        .name(name)
                        .continent(continent)
                        .country(country)
                        .build();
                cityRepository.save(city);
                log.info("✓ Created city: {} - {}", name, country);
            }
        }
    }

    private List<User> getRegularUsers() {
        return userRepository.findAll().stream()
                .filter(u -> u.getRole() == UserRole.USER)
                .toList();
    }

    private List<User> getOrganisers() {
        return userRepository.findAll().stream()
                .filter(u -> u.getRole() == UserRole.ORGANISER)
                .toList();
    }

    private void seedEvents() {
        List<User> organisers = getOrganisers();
        List<Category> categories = categoryRepository.findAll();
        List<City> cities = cityRepository.findAll();

        if (organisers.isEmpty() || categories.isEmpty()) {
            log.warn("No organisers or categories available. Skipping event seeding.");
            return;
        }

        Object[][][] events = {
            // TechViet Events (Technology)
            {
                {"AI Summit Vietnam 2026", "Join Vietnam's largest AI conference featuring industry leaders from Google, Microsoft, and OpenAI. Discover the latest trends in artificial intelligence, machine learning, and deep learning.", "Technology", "Ho Chi Minh", "0", "150000000", "5000000", "200", "Grand Hotel Saigon, 8 Dong Khoi Street, District 1", "10.7769", "106.7009"},
                {"Blockchain & Web3 Workshop", "Hands-on workshop covering blockchain fundamentals, smart contracts, and dApp development. Perfect for developers looking to enter the Web3 space.", "Technology", "Ha Noi", "1", "3000000", "1500000", "50", "Sofitel Legend Metropole, 15 Ngo Quyen Street", "21.0245", "105.8412"},
                {"Cloud Computing Conference", "Explore cloud-native architectures, Kubernetes, serverless computing, and DevOps best practices with AWS, Azure, and GCP experts.", "Technology", "Ho Chi Minh", "2", "8000000", "4000000", "150", "Rex Hotel Saigon, 141 Nguyen Hue Boulevard", "10.7740", "106.7011"}
            },
            // Sunflower Media (Entertainment)
            {
                {"Sunset Music Festival 2026", "Experience an unforgettable evening of electronic dance music featuring top DJs from Vietnam and abroad. Beach party vibes with stunning sunset views.", "Music & Entertainment", "Da Nang", "3", "2500000", "1200000", "1000", "My Khe Beach, Phuoc Thuan Ward", "16.0471", "108.2425"},
                {"Jazz Night at the Opera", "An elegant evening of contemporary jazz performances by Vietnamese and international artists in the beautiful Saigon Opera House.", "Music & Entertainment", "Ho Chi Minh", "4", "1500000", "800000", "300", "Saigon Opera House, 7 Cong Lam Quan Street", "10.7791", "106.7006"},
                {"Cultural Heritage Festival", "Celebrate Vietnamese traditional culture with folk music, dance performances, art exhibitions, and local crafts from all regions.", "Arts & Culture", "Ha Noi", "5", "500000", "200000", "500", "Temple of Literature, 58 Quoc Tu Giam Street", "21.0278", "105.8342"}
            },
            // GreenLife Foundation (Non-profit)
            {
                {"Ocean Cleanup Initiative", "Join our beach cleanup campaign to protect marine life. Educational workshops on plastic pollution and sustainable living included.", "Climate & Sustainability", "Da Nang", "6", "0", "0", "200", "Non Nuoc Beach, Hoa Hai Ward", "15.9952", "108.2627"},
                {"Tree Planting Day", "Community tree planting event in urban areas. Learn about native species, urban forestry, and climate action.", "Climate & Sustainability", "Ho Chi Minh", "7", "0", "0", "300", "Tao Dan Park, Nguyen Thi Minh Khai Street", "10.7742", "106.6900"},
                {"Mental Health Awareness Workshop", "Free workshop on mental health, stress management, and mindfulness practices. Led by certified psychologists.", "Health & Wellness", "Ha Noi", "8", "0", "0", "100", "Hoan Kiem Lake Area, Old Quarter", "21.0285", "105.8542"}
            },
            // StartupVN Hub (Business)
            {
                {"Startup Pitch Night #50", "Watch 10 promising startups pitch to top VCs and angel investors. Great networking opportunity for founders and investors.", "Startup & Innovation", "Ho Chi Minh", "9", "200000", "100000", "150", "Dreamplex, 19th Floor, Bitexco Tower", "10.7717", "106.7040"},
                {"Venture Capital Summit", "Connect with leading venture capitalists, learn about fundraising strategies, and discover investment trends in Southeast Asia.", "Business & Finance", "Ha Noi", "10", "5000000", "2500000", "80", "Lotte Center Hanoi, 54 Lieu Giai Street", "21.0293", "105.8127"},
                {"Digital Marketing Masterclass", "Learn growth hacking, SEO, content marketing, and social media strategies from successful marketing leaders.", "Business & Finance", "Ho Chi Minh", "11", "1500000", "800000", "100", "Saigon Innovation Hub, 24B Dinh Tien Hoang", "10.7807", "106.6990"}
            },
            // Fitness Hub (Health)
            {
                {"Founder Fitness & Mental Health Day", "Free wellness event for startup founders. Includes yoga session, meditation workshop, and group therapy. Lunch and networking included.", "Health & Wellness", "Ho Chi Minh", "12", "0", "0", "50", "Nguyen Hue Walking Street, District 1", "10.7743", "106.7013"},
                {"Saigon Marathon 2026", "Annual marathon event with full marathon, half marathon, and 10K categories. Professional timing and medals for all finishers.", "Sports & Fitness", "Ho Chi Minh", "13", "800000", "500000", "2000", "September 23 Park, Pham Ngu Lao Street", "10.7677", "106.6918"},
                {"Yoga & Meditation Retreat", "Weekend retreat focusing on yoga practice, meditation techniques, and holistic wellness in a peaceful natural setting.", "Health & Wellness", "Da Nang", "13", "2000000", "1200000", "50", "Ba Na Hills, Hoa Vang District", "15.9066", "107.9949"},
                {"CrossFit Championship", "Competitive CrossFit event for athletes of all levels. Prizes for winners, community vibes for everyone.", "Sports & Fitness", "Ha Noi", "14", "600000", "400000", "100", "Westlake Gym, 152 Xuan Dieu Street", "21.0583", "105.8237"}
            },
            // Food Fest (Food)
            {
                {"Street Food Festival", "Taste the best street food from all over Vietnam and Asia. Live cooking demonstrations and food competitions.", "Food & Beverage", "Ho Chi Minh", "15", "100000", "50000", "3000", "Nguyen Hue Walking Street, District 1", "10.7743", "106.7013"},
                {"Wine & Dine Experience", "Premium wine tasting paired with gourmet dishes from top restaurants. Sommelier-guided experience.", "Food & Beverage", "Ha Noi", "16", "3000000", "1500000", "80", "Intercontinental Hotel, 1A Lang Ha Street", "21.0175", "105.8254"},
                {"Vegan Food Fair", "Discover delicious plant-based cuisine, attend cooking workshops, and learn about sustainable eating habits.", "Food & Beverage", "Da Nang", "17", "80000", "40000", "500", "Son Tra Night Market, An Thuong Area", "16.0536", "108.2586"}
            },
            // Art Space (Arts)
            {
                {"Contemporary Art Exhibition", "Curated exhibition featuring works from emerging and established Vietnamese contemporary artists.", "Arts & Culture", "Ho Chi Minh", "18", "200000", "100000", "200", "The Factory Contemporary Arts Centre, 165 Nguyen Van Huong", "10.8014", "106.7337"},
                {"Photography Workshop", "Learn composition, lighting, and post-processing techniques from award-winning photographers.", "Photography", "Da Nang", "19", "1200000", "600000", "30", "Dragon Bridge Area, Tran Hung Dao Street", "16.0678", "108.2208"}
            },
            // EduVietnam (Education)
            {
                {"Career Fair 2026", "Meet recruiters from top tech companies, attend career workshops, and discover job opportunities in various industries.", "Education & Career", "Ho Chi Minh", "20", "0", "0", "1500", "Tan Binh Exhibition Centre, 446 Hoang Van Thu", "10.7996", "106.6518"},
                {"IELTS Masterclass", "Intensive IELTS preparation workshop with band 9 instructors. Tips and strategies for all test sections.", "Education & Career", "Ha Noi", "21", "500000", "300000", "100", "British Council, 20 Hai Ba Trung Street", "21.0230", "105.8520"}
            }
        };

        LocalDateTime now = LocalDateTime.now();
        int eventIndex = 0;

        for (Object[][] orgEvents : events) {
            User organiser = organisers.get(eventIndex % organisers.size());

            for (Object[] eventData : orgEvents) {
                String title = (String) eventData[0];

                if (eventRepository.findByTitle(title).isPresent()) {
                    eventIndex++;
                    continue;
                }

                String description = (String) eventData[1];
                String categoryName = (String) eventData[2];
                String cityName = (String) eventData[3];
                int imgIdx = Integer.parseInt((String) eventData[4]);
                long priceVnd = Long.parseLong((String) eventData[5]);
                long earlyPriceVnd = Long.parseLong((String) eventData[6]);
                int capacity = Integer.parseInt((String) eventData[7]);
                String venue = (String) eventData[8];
                double lat = Double.parseDouble((String) eventData[9]);
                double lng = Double.parseDouble((String) eventData[10]);

                Category category = categories.stream()
                        .filter(c -> c.getName().equalsIgnoreCase(categoryName))
                        .findFirst()
                        .orElse(categories.get(0));

                City city = cities.stream()
                        .filter(c -> c.getName().equalsIgnoreCase(cityName))
                        .findFirst()
                        .orElse(cities.get(0));

                LocalDateTime startTime = now.plusDays(10 + eventIndex * 3).withHour(14).withMinute(0).withSecond(0);
                LocalDateTime endTime = startTime.plusHours(4);
                LocalDateTime regDeadline = startTime.minusDays(1);

                Event event = Event.builder()
                        .title(title)
                        .description(description)
                        .imageUrl(EVENT_IMAGE_URLS[imgIdx % EVENT_IMAGE_URLS.length])
                        .startTime(startTime)
                        .endTime(endTime)
                        .registrationDeadline(regDeadline)
                        .venue(venue)
                        .address(city.getName() + ", " + city.getCountry())
                        .latitude(lat)
                        .longitude(lng)
                        .ticketPrice(BigDecimal.valueOf(priceVnd))
                        .isFree(priceVnd == 0)
                        .capacity(capacity)
                        .approvedCount(0)
                        .status(EventStatus.PUBLISHED)
                        .visibility(EventVisibility.PUBLIC)
                        .requiresApproval(true)
                        .recurrenceType(RecurrenceType.NONE)
                        .organiser(organiser)
                        .category(category)
                        .city(city)
                        .build();

                eventRepository.save(event);
                log.info("✓ Created Event: '{}' by {} in {}", title, organiser.getFullName(), city.getName());
                eventIndex++;
            }
        }
    }

    private void seedRegistrationQuestions() {
        List<Event> events = eventRepository.findAll();
        int questionIndex = 0;

        // Registration question templates for different event types
        String[][] questionTemplates = {
            {"What are your learning objectives for this event?", "TEXT"},
            {"Why do you want to attend this event?", "TEXT"},
            {"What is your current job title?", "TEXT"},
            {"Which company do you work for?", "TEXT"},
            {"How did you hear about this event?", "TEXT"},
            {"What topics are you most interested in?", "TEXTAREA"},
            {"Do you have any dietary requirements?", "TEXT"},
            {"Share your LinkedIn profile URL", "TEXT"},
            {"What challenges are you facing in your industry?", "TEXTAREA"},
            {"What do you hope to gain from networking at this event?", "TEXTAREA"}
        };

        for (Event event : events) {
            // Check if questions already exist
            if (event.getRegistrationQuestions() != null && !event.getRegistrationQuestions().isEmpty()) {
                continue;
            }

            // Free events and events requiring approval get registration questions
            boolean shouldAddQuestions = event.isFree() || event.isRequiresApproval();
            if (!shouldAddQuestions) {
                continue;
            }

            // Add 2-4 questions per event
            int numQuestions = 2 + (questionIndex % 3);
            int startIdx = questionIndex % questionTemplates.length;

            for (int i = 0; i < numQuestions; i++) {
                int qIdx = (startIdx + i) % questionTemplates.length;
                String[] template = questionTemplates[qIdx];

                RegistrationQuestion question = RegistrationQuestion.builder()
                        .event(event)
                        .questionText(template[0])
                        .questionType(QuestionType.valueOf(template[1]))
                        .required(true)
                        .displayOrder(i)
                        .build();

                entityManager.persist(question);
            }

            // Flush every 10 events to avoid memory issues
            if (questionIndex % 10 == 0) {
                entityManager.flush();
            }

            log.info("✓ Added {} registration questions for event: {}", numQuestions, event.getTitle());
            questionIndex++;
        }

        entityManager.flush();
        log.info("✓ Created registration questions for {} events", questionIndex);
    }

    private void seedTicketTypes() {
        List<Event> events = eventRepository.findAll();

        for (Event event : events) {
            if (ticketTypeRepository.findAll().stream().anyMatch(t -> t.getEvent().getId().equals(event.getId()))) {
                continue;
            }

            List<TicketType> ticketTypes = new ArrayList<>();

            if (event.isFree()) {
                // Free events - single free ticket
                TicketType freeTicket = TicketType.builder()
                        .event(event)
                        .name("General Admission")
                        .description("Free entry to the event")
                        .price(BigDecimal.ZERO)
                        .quantity(event.getCapacity())
                        .maxPerOrder(5)
                        .isVisible(true)
                        .displayOrder(0)
                        .build();
                ticketTypes.add(freeTicket);
            } else {
                // Paid events - multiple ticket types
                BigDecimal basePrice = event.getTicketPrice();

                // Early Bird
                TicketType earlyBird = TicketType.builder()
                        .event(event)
                        .name("Early Bird")
                        .description("Limited early bird tickets at special price. Valid ID required at check-in.")
                        .price(basePrice.multiply(BigDecimal.valueOf(0.6)))
                        .quantity(event.getCapacity() / 4)
                        .soldCount(event.getCapacity() / 8)
                        .maxPerOrder(3)
                        .isVisible(true)
                        .displayOrder(0)
                        .saleStartDate(LocalDateTime.now().minusDays(30))
                        .saleEndDate(event.getStartTime().minusDays(7))
                        .build();
                ticketTypes.add(earlyBird);

                // Regular
                TicketType regular = TicketType.builder()
                        .event(event)
                        .name("Regular Ticket")
                        .description("Standard admission with access to all sessions and materials")
                        .price(basePrice.multiply(BigDecimal.valueOf(0.85)))
                        .quantity(event.getCapacity() / 2)
                        .soldCount(event.getCapacity() / 4)
                        .maxPerOrder(5)
                        .isVisible(true)
                        .displayOrder(1)
                        .build();
                ticketTypes.add(regular);

                // VIP
                TicketType vip = TicketType.builder()
                        .event(event)
                        .name("VIP Experience")
                        .description("Premium seating, backstage access, exclusive networking lunch, and gift bag")
                        .price(basePrice.multiply(BigDecimal.valueOf(1.5)))
                        .quantity(event.getCapacity() / 4)
                        .soldCount(event.getCapacity() / 10)
                        .maxPerOrder(2)
                        .isVisible(true)
                        .displayOrder(2)
                        .build();
                ticketTypes.add(vip);
            }

            ticketTypeRepository.saveAll(ticketTypes);
            log.info("✓ Created {} ticket types for: {}", ticketTypes.size(), event.getTitle());
        }
    }

    private void fixFreeEventTicketTypes() {
        List<Event> events = eventRepository.findAll();
        int fixedCount = 0;
        int freeEventsChecked = 0;

        log.info("✓ Checking {} events for ticket type issues", events.size());

        for (Event event : events) {
            if (!event.isFree()) {
                continue;
            }

            freeEventsChecked++;
            List<TicketType> existingTicketTypes = ticketTypeRepository.findAll().stream()
                    .filter(t -> t.getEvent().getId().equals(event.getId()))
                    .toList();

            // Check if any ticket type has non-zero price
            boolean hasPaidTickets = existingTicketTypes.stream()
                    .anyMatch(t -> t.getPrice().compareTo(BigDecimal.ZERO) > 0);

            if (hasPaidTickets) {
                // Delete all existing ticket types for this event
                ticketTypeRepository.deleteAll(existingTicketTypes);
                log.info("✓ Removed {} paid ticket types for free event: {}", existingTicketTypes.size(), event.getTitle());

                // Create single free ticket
                TicketType freeTicket = TicketType.builder()
                        .event(event)
                        .name("General Admission")
                        .description("Free entry to the event")
                        .price(BigDecimal.ZERO)
                        .quantity(event.getCapacity())
                        .maxPerOrder(5)
                        .isVisible(true)
                        .displayOrder(0)
                        .build();
                ticketTypeRepository.save(freeTicket);
                log.info("✓ Created free ticket for: {}", event.getTitle());
                fixedCount++;
            }
        }

        log.info("✓ Checked {} free events, fixed {} events with incorrect ticket types", freeEventsChecked, fixedCount);

        if (fixedCount > 0) {
            log.info("✓ Fixed ticket types for {} free events", fixedCount);
        }
    }

    private void seedSpeakers() {
        List<Event> events = eventRepository.findAll();

        String[][] speakerData = {
            {"Dr. Sarah Chen", "AI Research Lead at Google DeepMind", "Former Stanford professor, pioneer in neural architecture search"},
            {"Michael Torres", "Principal Cloud Architect at Microsoft", "20+ years building distributed systems, Azure MVP"},
            {"Emma Williams", "Founder & CEO at TechStart", "Serial entrepreneur, 3x exits, Y Combinator alumna"},
            {"Prof. James Nguyen", "Director of AI Lab at VinAI", "PhD from MIT, published 100+ papers in machine learning"},
            {"Lisa Park", "Head of Developer Relations at Vercel", "React core contributor, international speaker"},
            {"David Le", "Blockchain Lead at ConsenSys", "Built DeFi protocols with $1B+ TVL"},
            {"Dr. Anna Tran", "Chief Sustainability Officer at GreenTech", "Climate tech investor, TEDx speaker"},
            {"Robert Kim", "Growth Marketing Director at Grab", "Scaled user base from 0 to 50M in Southeast Asia"}
        };

        int speakerIndex = 0;
        for (Event event : events) {
            if (speakerRepository.findAll().stream().anyMatch(s -> s.getEvent().getId().equals(event.getId()))) {
                continue;
            }

            // Add 1-3 speakers per event
            int numSpeakers = 1 + (speakerIndex % 3);
            for (int i = 0; i < numSpeakers && speakerIndex < speakerData.length; i++) {
                Speaker speaker = Speaker.builder()
                        .name(speakerData[speakerIndex % speakerData.length][0])
                        .title(speakerData[speakerIndex % speakerData.length][1])
                        .bio(speakerData[speakerIndex % speakerData.length][2])
                        .imageUrl(AVATAR_URLS[(speakerIndex + 3) % AVATAR_URLS.length])
                        .event(event)
                        .build();
                speakerRepository.save(speaker);
                speakerIndex++;
            }
        }
        log.info("✓ Created speakers for events");
    }

    private void seedRegistrations() {
        List<User> users = getRegularUsers();
        List<Event> events = eventRepository.findAll();
        List<TicketType> ticketTypes = ticketTypeRepository.findAll();

        if (users.isEmpty() || ticketTypes.isEmpty()) {
            log.warn("No users or ticket types available for registrations");
            return;
        }

        Random random = new Random(123);
        int registrationIndex = 0;

        for (Event event : events) {
            List<TicketType> eventTicketTypes = ticketTypes.stream()
                    .filter(t -> t.getEvent().getId().equals(event.getId()))
                    .toList();

            if (eventTicketTypes.isEmpty()) continue;

            // Create registrations for 30-80% of capacity
            int numRegistrations = event.getCapacity() * (30 + random.nextInt(50)) / 100;
            numRegistrations = Math.min(numRegistrations, users.size());

            List<User> shuffledUsers = new ArrayList<>(users);
            Collections.shuffle(shuffledUsers, random);

            for (int i = 0; i < numRegistrations && i < shuffledUsers.size(); i++) {
                User user = shuffledUsers.get(i);

                // Check if already registered
                if (registrationRepository.findByUserIdAndEventId(user.getId(), event.getId()).isPresent()) {
                    continue;
                }

                TicketType ticketType = eventTicketTypes.get(random.nextInt(eventTicketTypes.size()));

                RegistrationStatus status = RegistrationStatus.values()[random.nextInt(RegistrationStatus.values().length)];
                if (status == RegistrationStatus.REJECTED || status == RegistrationStatus.CANCELLED) status = RegistrationStatus.APPROVED;

                LocalDateTime now = LocalDateTime.now();
                LocalDateTime createdAt = now.minusDays(random.nextInt(30));

                Registration registration = Registration.builder()
                        .user(user)
                        .event(event)
                        .ticketType(ticketType)
                        .quantity(1 + random.nextInt(3))
                        .status(status)
                        .ticketCode("TKT" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                        .approvedAt(status == RegistrationStatus.APPROVED ? createdAt.plusHours(1) : null)
                        .waitingListPosition(status == RegistrationStatus.WAITING_LIST ? random.nextInt(50) + 1 : null)
                        .priorityScore(50 + random.nextInt(50))
                        .reminderSent(random.nextBoolean())
                        .reminderSentAt(now.minusDays(1))
                        .createdAt(createdAt)
                        .build();

                registrationRepository.save(registration);
                registrationIndex++;
            }

            // Update event approved count
            long approvedCount = registrationRepository.findAllByEventIdAndStatus(event.getId(), RegistrationStatus.APPROVED).size();
            event.setApprovedCount((int) approvedCount);
            eventRepository.save(event);
        }

        log.info("✓ Created {} registrations", registrationIndex);
    }

    private void seedCertificates() {
        List<Registration> registrations = registrationRepository.findAll();

        int certIndex = 0;
        for (Registration registration : registrations) {
            if (registration.getStatus() != RegistrationStatus.APPROVED) continue;

            if (certificateRepository.findByRegistrationId(registration.getId()).isPresent()) {
                continue;
            }

            // Generate certificate for past events
            if (registration.getEvent().getEndTime().isBefore(LocalDateTime.now())) {
                Certificate certificate = Certificate.builder()
                        .registration(registration)
                        .certificateCode("CERT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase().replace("-", ""))
                        .certificateUrl("https://images.unsplash.com/photo-1589330694653-4a8b7f2b6d6a?w=800&h=600&fit=crop")
                        .generatedAt(LocalDateTime.now())
                        .build();
                certificateRepository.save(certificate);
                certIndex++;
            }
        }
        log.info("✓ Generated {} certificates for past events", certIndex);
    }

    private void seedReviews() {
        List<Registration> registrations = registrationRepository.findAllByStatus(RegistrationStatus.APPROVED);
        List<Event> events = eventRepository.findAll();

        if (registrations.isEmpty()) return;

        Random random = new Random(456);
        int reviewIndex = 0;

        for (Registration registration : registrations) {
            // Only review past events, 50% chance
            if (registration.getEvent().getEndTime().isAfter(LocalDateTime.now())) continue;
            if (random.nextFloat() > 0.5f) continue;

            // Check if already reviewed
            if (reviewRepository.findByUserIdAndEventId(registration.getUser().getId(), registration.getEvent().getId()).isPresent()) {
                continue;
            }

            int rating = 3 + random.nextInt(3); // 3-5 stars for approved attendees
            String[] comments = {
                "Great event! Learned a lot and met amazing people.",
                "Well organized, professional speakers, valuable content.",
                "Excellent networking opportunity. Will definitely attend again!",
                "Good event overall, though venue was a bit crowded.",
                "Amazing experience! The speakers were inspiring.",
                "Very informative sessions and great food.",
                "Best tech event I've attended in Vietnam!",
                "Helpful workshops and friendly community."
            };

            Review review = Review.builder()
                    .user(registration.getUser())
                    .event(registration.getEvent())
                    .rating(rating)
                    .comment(comments[random.nextInt(comments.length)])
                    .toxicityScore(5 + random.nextInt(20))
                    .flagged(false)
                    .build();

            reviewRepository.save(review);
            reviewIndex++;
        }
        log.info("✓ Created {} event reviews", reviewIndex);
    }

    private void seedFollows() {
        List<User> users = getRegularUsers();
        List<OrganiserProfile> organisers = organiserProfileRepository.findAll();

        if (users.isEmpty() || organisers.isEmpty()) return;

        Random random = new Random(789);
        int followIndex = 0;

        for (User user : users) {
            // Each user follows 2-5 organisers
            int numFollows = 2 + random.nextInt(4);
            List<OrganiserProfile> shuffled = new ArrayList<>(organisers);
            Collections.shuffle(shuffled, random);

            for (int i = 0; i < numFollows && i < shuffled.size(); i++) {
                if (followRepository.findByFollowerIdAndOrganiserId(user.getId(), shuffled.get(i).getId()).isPresent()) {
                    continue;
                }

                Follow follow = Follow.builder()
                        .follower(user)
                        .organiser(shuffled.get(i))
                        .build();
                followRepository.save(follow);
                followIndex++;
            }
        }
        log.info("✓ Created {} follow relationships", followIndex);
    }

    private void seedConnections() {
        List<User> users = getRegularUsers();

        if (users.size() < 2) return;

        Random random = new Random(101);
        int connectionIndex = 0;

        for (int i = 0; i < users.size(); i++) {
            // Each user sends 3-8 connection requests
            int numRequests = 3 + random.nextInt(6);

            for (int j = 0; j < numRequests; j++) {
                int receiverIdx = random.nextInt(users.size());
                if (receiverIdx == i) continue;

                User sender = users.get(i);
                User receiver = users.get(receiverIdx);

                // Check existing request (either direction)
                var existing = connectionRequestRepository.findBySenderIdAndReceiverId(sender.getId(), receiver.getId());
                if (existing.isPresent()) continue;

                ConnectionStatus status = ConnectionStatus.values()[random.nextInt(ConnectionStatus.values().length)];

                ConnectionRequest request = ConnectionRequest.builder()
                        .sender(sender)
                        .receiver(receiver)
                        .status(status)
                        .message(status == ConnectionStatus.ACCEPTED ? "Great connecting with you at the event!" : null)
                        .respondedAt(status != ConnectionStatus.PENDING ? LocalDateTime.now().minusDays(random.nextInt(7)) : null)
                        .build();

                connectionRequestRepository.save(request);
                connectionIndex++;
            }
        }
        log.info("✓ Created {} connection requests", connectionIndex);
    }

    private void seedBookmarks() {
        List<User> users = getRegularUsers();
        List<Event> events = eventRepository.findAll();

        if (users.isEmpty() || events.isEmpty()) return;

        Random random = new Random(202);
        int bookmarkIndex = 0;

        for (User user : users) {
            // Each user bookmarks 2-6 events
            int numBookmarks = 2 + random.nextInt(5);
            List<Event> shuffled = new ArrayList<>(events);
            Collections.shuffle(shuffled, random);

            for (int i = 0; i < numBookmarks && i < shuffled.size(); i++) {
                Event event = shuffled.get(i);

                if (bookmarkRepository.findByUserIdAndEventId(user.getId(), event.getId()).isPresent()) {
                    continue;
                }

                Bookmark bookmark = Bookmark.builder()
                        .user(user)
                        .event(event)
                        .build();
                bookmarkRepository.save(bookmark);
                bookmarkIndex++;
            }
        }
        log.info("✓ Created {} bookmarks", bookmarkIndex);
    }
}
