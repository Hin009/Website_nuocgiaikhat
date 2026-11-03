package vn.drinkstore.common;

import java.sql.SQLException;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.BadSqlGrammarException;
import org.springframework.jdbc.CannotGetJdbcConnectionException;
import org.springframework.mock.web.MockHttpServletRequest;
import static org.junit.jupiter.api.Assertions.*;

class ErrorsTest {
    private final Errors errors = new Errors();
    private final MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/health");

    @Test void rejectedDatabasePasswordReturnsServiceUnavailableWithoutExposingDetails() {
        var exception = new CannotGetJdbcConnectionException("connection failed", new SQLException("private credentials", "28P01"));
        var response = errors.database(exception, request);
        assertEquals(503, response.getStatusCode().value());
        assertFalse(response.getBody().toString().contains("private credentials"));
    }

    @Test void duplicateDataRemainsConflict() {
        assertEquals(409, errors.database(new DataIntegrityViolationException("duplicate"), request).getStatusCode().value());
    }

    @Test void missingTableIsServerErrorRatherThanDataConflict() {
        var exception = new BadSqlGrammarException("query", "select secret", new SQLException("missing table", "42P01"));
        var response = errors.database(exception, request);
        assertEquals(500, response.getStatusCode().value());
        assertFalse(response.getBody().toString().contains("select secret"));
    }
}
