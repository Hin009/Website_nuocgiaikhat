package vn.drinkstore.security;

import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.*;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {
    @Bean PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(12); }
    @Bean SecurityFilterChain security(HttpSecurity http, BearerFilter filter) throws Exception {
        return http.csrf(c->c.disable()).cors(c->{})
            .sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(a->a
                .requestMatchers(HttpMethod.OPTIONS,"/**").permitAll()
                .requestMatchers("/api/v1/auth/login","/api/v1/auth/register").permitAll()
                .requestMatchers(HttpMethod.GET,"/api/v1/catalog/**","/api/v1/media/products/*","/api/v1/health").permitAll()
                .anyRequest().authenticated())
            .exceptionHandling(e->e.authenticationEntryPoint((q,r,x)->{
                r.setStatus(401); r.setContentType("application/json;charset=UTF-8"); r.getWriter().write("{\"status\":401,\"message\":\"Vui lòng đăng nhập\"}");
            }).accessDeniedHandler((q,r,x)->{
                r.setStatus(403); r.setContentType("application/json;charset=UTF-8"); r.getWriter().write("{\"status\":403,\"message\":\"Bạn không có quyền thực hiện\"}");
            }))
            .addFilterBefore(filter,UsernamePasswordAuthenticationFilter.class).build();
    }
    @Bean CorsConfigurationSource corsConfigurationSource(@Value("${app.cors-origins}") List<String> origins) {
        var c=new CorsConfiguration(); c.setAllowedOrigins(origins);
        c.setAllowedMethods(List.of("GET","POST","PUT","PATCH","DELETE","OPTIONS"));
        c.setAllowedHeaders(List.of("Authorization","Content-Type"));
        var source=new UrlBasedCorsConfigurationSource(); source.registerCorsConfiguration("/**",c); return source;
    }
}
