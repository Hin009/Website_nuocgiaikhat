package vn.drinkstore.security;

import java.io.IOException;
import java.util.List;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import vn.drinkstore.common.Db;

@Component
public class BearerFilter extends OncePerRequestFilter {
    private final Db db;
    public BearerFilter(Db db) { this.db=db; }
    @Override protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain) throws ServletException, IOException {
        String h=request.getHeader("Authorization");
        if(h!=null && h.startsWith("Bearer ") && h.length()<512) {
            var rows=db.jdbc().queryForList("select a.id from phien_xac_thuc s join tai_khoan a on a.id=s.tai_khoan_id where s.token_hash=? and not s.da_thu_hoi and s.het_han>now() and a.trang_thai='ACTIVE'", Tokens.hash(h.substring(7)));
            if(!rows.isEmpty()) SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(Db.n(rows.getFirst(),"id"),null,List.of()));
        }
        chain.doFilter(request,response);
    }
}
