package vn.drinkstore.common;

import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class Db {
    private final JdbcTemplate jdbc;
    public Db(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    public JdbcTemplate jdbc() { return jdbc; }
    public List<Map<String,Object>> rows(String sql,Object... args) {
        return jdbc.query(sql,new org.springframework.jdbc.core.ColumnMapRowMapper() {
            @Override protected Object getColumnValue(java.sql.ResultSet rs,int index) throws java.sql.SQLException {
                Object value=super.getColumnValue(rs,index);
                if(value instanceof java.sql.Array array) {
                    try { return array.getArray(); } finally { array.free(); }
                }
                return value;
            }
        },args);
    }
    public Map<String,Object> one(String sql, Object... args) {
        var rows = rows(sql, args);
        if (rows.isEmpty()) throw ApiException.missing();
        return rows.getFirst();
    }
    public <T> T entity(Class<T> type,String sql,Object... args) {
        var rows=jdbc.query(sql,new org.springframework.jdbc.core.DataClassRowMapper<>(type),args);
        if(rows.isEmpty()) throw ApiException.missing();
        return rows.getFirst();
    }
    public long id(String sql, Object... args) { return ((Number)one(sql,args).get("id")).longValue(); }
    public long number(String sql, Object... args) { return jdbc.queryForObject(sql, Long.class, args); }
    public void audit(long account, String action, String target, long id) {
        jdbc.update("insert into nhat_ky_hoat_dong(tai_khoan_id,hanh_dong,doi_tuong,doi_tuong_id) values (?,?,?,?)", account,action,target,id);
    }
    public static long n(Map<String,Object> row, String field) { return ((Number)row.get(field)).longValue(); }
    public static java.math.BigDecimal money(Map<String,Object> row, String field) { return new java.math.BigDecimal(row.get(field).toString()); }
    public Map<String,Object> page(String select, String count, List<Object> args, int page, int size) {
        if (page < 0 || size < 1 || size > 100 || page > 1000000) throw ApiException.bad("page >= 0; size từ 1 đến 100");
        long total=number(count,args.toArray());
        var params=new ArrayList<>(args); params.add(size); params.add((long)page*size);
        return Map.of("items",rows(select+" limit ? offset ?",params.toArray()),"page",page,"size",size,"total",total);
    }
}
