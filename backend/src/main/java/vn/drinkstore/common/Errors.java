package vn.drinkstore.common;

import java.time.Instant;
import java.util.Map;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.TransientDataAccessResourceException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.sql.SQLException;
import org.springframework.http.*;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

@RestControllerAdvice
public class Errors {
    private static final Logger log = LoggerFactory.getLogger(Errors.class);
    private ResponseEntity<?> error(HttpStatus status, String message, HttpServletRequest request) {
        return ResponseEntity.status(status).body(Map.of("status", status.value(), "message", message,
            "path", request.getRequestURI(), "timestamp", Instant.now().toString()));
    }
    @ExceptionHandler(org.springframework.web.multipart.MaxUploadSizeExceededException.class)
    ResponseEntity<?> tooLarge(Exception e,HttpServletRequest r) { return error(HttpStatus.PAYLOAD_TOO_LARGE,"Ảnh không được vượt quá 5 MB",r); }
    @ExceptionHandler(ApiException.class)
    ResponseEntity<?> api(ApiException e, HttpServletRequest r) { return error(e.status, e.getMessage(), r); }
    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<?> forbidden(AccessDeniedException e, HttpServletRequest r) { return error(HttpStatus.FORBIDDEN, "Bạn không có quyền thực hiện", r); }
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<?> validation(MethodArgumentNotValidException e, HttpServletRequest r) {
        return error(HttpStatus.BAD_REQUEST, e.getBindingResult().getFieldErrors().stream()
            .map(f -> f.getField() + ": " + f.getDefaultMessage()).reduce((a,b) -> a + "; " + b).orElse("Dữ liệu không hợp lệ"), r);
    }
    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class, HandlerMethodValidationException.class})
    ResponseEntity<?> invalid(Exception e, HttpServletRequest r) { return error(HttpStatus.BAD_REQUEST, "Kiểm tra kiểu dữ liệu và các trường gửi lên", r); }
    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<?> database(DataAccessException e, HttpServletRequest r) {
        String sqlState = null;
        for (Throwable cause = e; cause != null; cause = cause.getCause()) {
            if (cause instanceof SQLException sql && sql.getSQLState() != null) sqlState = sql.getSQLState();
        }
        // Log the category only; SQL exception messages can contain sensitive row values.
        log.warn("Database request failed: path={}, category={}, sqlState={}", r.getRequestURI(), e.getClass().getSimpleName(), sqlState);
        if (e instanceof DataAccessResourceFailureException || e instanceof TransientDataAccessResourceException
            || (sqlState != null && (sqlState.startsWith("08") || sqlState.startsWith("28") || sqlState.equals("3D000")))) {
            return error(HttpStatus.SERVICE_UNAVAILABLE,
                "Không kết nối được database. Kiểm tra PostgreSQL và cấu hình DB_URL, DB_USERNAME, DB_PASSWORD của backend", r);
        }
        if (e instanceof DataIntegrityViolationException || (sqlState != null && sqlState.equals("P0001"))) {
            return error(HttpStatus.CONFLICT, "Dữ liệu trùng, đang được sử dụng hoặc vi phạm điều kiện nghiệp vụ (trạng thái/số lượng)", r);
        }
        return error(HttpStatus.INTERNAL_SERVER_ERROR, "Lỗi truy vấn database. Kiểm tra schema và script SQL bổ sung của backend", r);
    }
}
