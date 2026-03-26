package com.luma.config;

import com.luma.entity.Category;
import com.luma.entity.City;
import com.luma.entity.OrganiserProfile;
import com.luma.entity.User;
import com.luma.entity.enums.UserRole;
import com.luma.entity.enums.UserStatus;
import com.luma.repository.CategoryRepository;
import com.luma.repository.CityRepository;
import com.luma.repository.OrganiserProfileRepository;
import com.luma.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final OrganiserProfileRepository organiserProfileRepository;
    private final CategoryRepository categoryRepository;
    private final CityRepository cityRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(String... args) {
        seedAdminUser();
        seedOrganiserUser();
        seedCategories();
        seedCities();
        log.info("=== Data seeding completed ===");
    }

    private void seedAdminUser() {
        if (!userRepository.existsByEmail("admin@luma.com")) {
            User admin = User.builder()
                    .email("admin@luma.com")
                    .password(passwordEncoder.encode("admin123"))
                    .fullName("LUMA Administrator")
                    .role(UserRole.ADMIN)
                    .status(UserStatus.ACTIVE)
                    .emailVerified(true)
                    .build();
            userRepository.save(admin);
            log.info("Created Admin account: admin@luma.com / admin123");
        }
    }

    private void seedOrganiserUser() {
        Object[][] organisers = {
            {"techviet@luma.com", "techviet123", "TechViet Events", "TechViet", "Leading technology event organizer in Vietnam"},
            {"sunflower@luma.com", "sunflower123", "Sunflower Media", "Sunflower Media", "Specializing in music and entertainment events"},
            {"greenlife@luma.com", "greenlife123", "GreenLife Foundation", "GreenLife Foundation", "Non-profit organization for environment and health"},
            {"startupvn@luma.com", "startupvn123", "StartupVN Hub", "StartupVN Hub", "Startup and innovation community"}
        };

        for (Object[] orgData : organisers) {
            String email = (String) orgData[0];
            String password = (String) orgData[1];
            String fullName = (String) orgData[2];
            String displayName = (String) orgData[3];
            String bio = (String) orgData[4];

            if (!userRepository.existsByEmail(email)) {
                User organiser = User.builder()
                        .email(email)
                        .password(passwordEncoder.encode(password))
                        .fullName(fullName)
                        .role(UserRole.ORGANISER)
                        .status(UserStatus.ACTIVE)
                        .emailVerified(true)
                        .build();
                organiser = userRepository.save(organiser);

                OrganiserProfile profile = OrganiserProfile.builder()
                        .user(organiser)
                        .displayName(displayName)
                        .bio(bio)
                        .contactEmail(email)
                        .verified(true)
                        .build();
                organiserProfileRepository.save(profile);
                log.info("Created Organiser account: {} / {}", email, password);
            }
        }
    }

    private void seedCategories() {
        String[] categories = {
            "Technology",
            "AI",
            "Climate",
            "Sports & Fitness",
            "Cryptocurrency",
            "Food & Beverage",
            "Arts & Culture",
            "Health & Wellness"
        };

        for (String name : categories) {
            if (!categoryRepository.existsByName(name)) {
                Category category = Category.builder()
                        .name(name)
                        .build();
                categoryRepository.save(category);
                log.info("Created category: {}", name);
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
            if (existingCity.isPresent()) {
                City city = existingCity.get();
                if (!city.getContinent().equals(continent)) {
                    city.setContinent(continent);
                    city.setCountry(country);
                    cityRepository.save(city);
                    log.info("Updated city continent: {} -> {}", name, continent);
                }
            } else {
                City city = City.builder()
                        .name(name)
                        .continent(continent)
                        .country(country)
                        .build();
                cityRepository.save(city);
                log.info("Created city: {} - {}", name, country);
            }
        }
    }
}
