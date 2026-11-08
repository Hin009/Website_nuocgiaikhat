package vn.drinkstore;

import java.math.BigDecimal;
import java.util.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.context.ApplicationContextInitializer;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.core.io.ClassPathResource;
import java.sql.DriverManager;
import java.nio.charset.StandardCharsets;
import vn.drinkstore.auth.AuthService;
import vn.drinkstore.common.*;
import vn.drinkstore.sales.*;
import vn.drinkstore.purchasing.*;
import vn.drinkstore.billing.BillingService;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Use an EMPTY, disposable PostgreSQL database. Tests roll back; schema/seed is installed once. */
@SpringBootTest(properties={
    "spring.datasource.url=${BACKEND_TEST_DB_URL}","spring.datasource.username=${BACKEND_TEST_DB_USER:backend_test}",
    "spring.datasource.password=${BACKEND_TEST_DB_PASSWORD:}","spring.sql.init.mode=never",
    "app.bootstrap.password=","app.upload-dir=.tools/test-uploads"
})
@AutoConfigureMockMvc
@Transactional
@EnabledIfEnvironmentVariable(named="BACKEND_TEST_DB_URL",matches=".*")
@ContextConfiguration(initializers=BackendIntegrationTest.Init.class)
class BackendIntegrationTest {
    static class Init implements ApplicationContextInitializer<ConfigurableApplicationContext> {
        @Override public void initialize(ConfigurableApplicationContext context) {
            String url=System.getenv("BACKEND_TEST_DB_URL");
            if(!url.contains("backend_test")) throw new IllegalArgumentException("Use a disposable database whose name contains backend_test");
            try(var c=DriverManager.getConnection(url,System.getenv().getOrDefault("BACKEND_TEST_DB_USER","backend_test"),System.getenv().getOrDefault("BACKEND_TEST_DB_PASSWORD",""));var s=c.createStatement()) {
                boolean initialized;
                try(var rs=s.executeQuery("select to_regclass('public.tai_khoan') is not null")) { rs.next(); initialized=rs.getBoolean(1); }
                if(initialized) return;
                // PostgreSQL dollar-quoted function bodies must be sent intact, not split on semicolons.
                s.execute(new ClassPathResource("testdb/beverage_store_test.sql").getContentAsString(StandardCharsets.UTF_8));
            } catch(Exception e) { throw new IllegalStateException("Cannot initialize disposable test database",e); }
        }
    }
    @Autowired Db db; @Autowired AuthService auth; @Autowired CartService carts; @Autowired OrderService orders;
    @Autowired PurchaseService purchases; @Autowired BillingService billing; @Autowired MockMvc mvc;
    @Autowired SupplierReturnService supplierReturns;
    @Autowired org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;
    @Autowired vn.drinkstore.reporting.ProductFinanceController productFinance;
    long account,customer,admin,employee,product,pack,supplier,address;
    @BeforeEach void setup() {
        account=((Number)auth.register("customer@test.invalid","TestPass123!","Test Customer").get("id")).longValue();
        customer=db.id("select id from khach_hang where tai_khoan_id=?",account);
        admin=auth.createAccount("admin@test.invalid","TestPass123!","QUAN_TRI_VIEN");
        employee=db.id("insert into nhan_vien(tai_khoan_id,ma_nhan_vien,ho_ten) values (?,'NV-TEST','Admin Test') returning id",admin);
        product=db.id("select id from san_pham where sku='SP001'");
        pack=db.id("select id from quy_cach_san_pham where san_pham_id=? and he_so_quy_doi=1",product);
        supplier=db.id("insert into nha_cung_cap(ten) values ('Test Supplier') returning id");
        db.jdbc().update("insert into nha_cung_cap_san_pham(nha_cung_cap_id,san_pham_id) values (?,?)",supplier,product);
        address=db.id("insert into dia_chi_giao_hang(khach_hang_id,ten_nguoi_nhan,so_dien_thoai,tinh_thanh,dia_chi) values (?,'Test','0900000000','HCM','123 ABC') returning id",customer);
        as(admin);
    }
    @AfterEach void clear() { SecurityContextHolder.clearContext(); }
    @Test void anonymousOtpResetChangesPasswordRevokesSessionsAndRejectsReplay() throws Exception {
        auth.login("customer@test.invalid","TestPass123!");
        UUID challenge=UUID.randomUUID();
        db.jdbc().update("insert into password_reset_challenge(id,tai_khoan_id,otp_hash,het_han) values (?,?,?,now()+interval '5 minutes')",challenge,account,passwordEncoder.encode("123456"));
        clear();
        mvc.perform(post("/api/v1/auth/password-reset/verify").contentType(MediaType.APPLICATION_JSON)
            .content("{\"challengeId\":\""+challenge+"\",\"code\":\"111111\"}"))
            .andExpect(status().isBadRequest());
        assertEquals(1,db.number("select so_lan_sai from password_reset_challenge where id=?",challenge));
        String response=mvc.perform(post("/api/v1/auth/password-reset/verify").contentType(MediaType.APPLICATION_JSON)
            .content("{\"challengeId\":\""+challenge+"\",\"code\":\"123456\"}"))
            .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String token=new com.fasterxml.jackson.databind.ObjectMapper().readTree(response).get("resetToken").asText();
        String complete="{\"challengeId\":\""+challenge+"\",\"resetToken\":\""+token+"\",\"newPassword\":\"ReplacementPass123!\"}";
        mvc.perform(post("/api/v1/auth/password-reset/complete").contentType(MediaType.APPLICATION_JSON).content(complete)).andExpect(status().isOk());
        assertEquals(0,db.number("select count(*) from phien_xac_thuc where tai_khoan_id=? and not da_thu_hoi",account));
        mvc.perform(post("/api/v1/auth/password-reset/complete").contentType(MediaType.APPLICATION_JSON).content(complete)).andExpect(status().isBadRequest());
        assertThrows(ApiException.class,()->auth.login("customer@test.invalid","TestPass123!"));
        assertNotNull(auth.login("customer@test.invalid","ReplacementPass123!").get("accessToken"));
    }
    void as(long id) { SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(id,null,List.of())); }
    long stock() { return db.number("select so_luong_co_ban from so_luong_san_pham where san_pham_id=?",product); }
    long receive(int quantity) {
        var po=(Map<?,?>)purchases.create(new PurchaseController.Create(supplier,null,List.of(new PurchaseController.Line(pack,quantity,new BigDecimal("8000")))));
        long id=((Number)po.get("id")).longValue();
        purchases.decide(id,new PurchaseController.Decision("DA_DUYET",null));
        long line=db.id("select id from chi_tiet_don_ncc where don_ncc_id=?",id);
        var receipt=(Map<?,?>)purchases.receipt(id,new PurchaseController.Receive(List.of(new PurchaseController.ReceiptLine(line,quantity,new BigDecimal("8000")))));
        long r=((Number)receipt.get("id")).longValue(); purchases.confirm(r); return r;
    }
    long checkout() {
        as(account); carts.put(customer,pack,2);
        return ((Number)((Map<?,?>)orders.checkout(customer,address,null,"COD",null)).get("id")).longValue();
    }
    @Test void selectedCheckoutUsesServerPricesAndLeavesOtherCartLines() {
        receive(100);
        long other=db.id("select id from quy_cach_san_pham where san_pham_id=? and he_so_quy_doi>1 order by he_so_quy_doi limit 1",product);
        as(account); carts.put(customer,pack,2); carts.put(customer,other,1);
        var quote=orders.quote(customer,List.of(pack),null);
        var price=Db.money(db.one("select gia_ban from quy_cach_san_pham where id=?",pack),"gia_ban");
        assertEquals(0,price.multiply(BigDecimal.valueOf(2)).compareTo((BigDecimal)quote.get("subtotal")));
        var order=(Map<?,?>)orders.checkout(customer,address,null,"COD",null,List.of(pack));
        assertEquals(quote.get("total"),order.get("tong_tien"));
        assertEquals(account,((Number)order.get("tai_khoan_khach_id")).longValue());
        assertEquals(1,db.number("select count(*) from chi_tiet_gio_hang where gio_hang_id=?",carts.cart(customer)));
        assertEquals(other,db.number("select quy_cach_id from chi_tiet_gio_hang where gio_hang_id=?",carts.cart(customer)));
        assertEquals(100,stock());
        orders.transition(((Number)order.get("id")).longValue(),"DA_HUY",customer,"Changed mind");
        assertEquals("Changed mind",db.one("select ghi_chu from lich_su_trang_thai_don where don_hang_id=? order by id desc limit 1",order.get("id")).get("ghi_chu"));
    }
    @Test void editorCreatesProfilesAndReceiptListIncludesProductDetails() throws Exception {
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        mvc.perform(post("/api/v1/management/account-editor").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"newstaff@test.invalid\",\"password\":\"TestPass123!\",\"fullName\":\"New Staff\",\"phone\":\"0900000000\",\"role\":\"NHAN_VIEN\",\"active\":true}"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.roles[0]").value("NHAN_VIEN")).andExpect(jsonPath("$.mat_khau_hash").doesNotExist());
        assertEquals(1,db.number("select count(*) from nhan_vien n join tai_khoan a on a.id=n.tai_khoan_id where a.email='newstaff@test.invalid'"));
        as(admin); receive(10);
        mvc.perform(get("/api/v1/receipts").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items[0].items[0].san_pham_id").value(product))
            .andExpect(jsonPath("$.items[0].nha_cung_cap").value("Test Supplier"));
        mvc.perform(get("/api/v1/management/accounts").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items[0].roles").isArray())
            .andExpect(jsonPath("$.items[0].mat_khau_hash").doesNotExist());
    }
    @Test void managementCustomerListsUseDefaultOrFirstSavedAddress() throws Exception {
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        String accountPath="$.items[?(@.id == "+account+")].dia_chi";
        mvc.perform(get("/api/v1/staff/customers").param("q","Test Customer").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items[0].dia_chi").value("123 ABC, HCM"));
        mvc.perform(get("/api/v1/management/accounts").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(jsonPath(accountPath).value(org.hamcrest.Matchers.hasItem("123 ABC, HCM")));
        db.jdbc().update("insert into dia_chi_giao_hang(khach_hang_id,ten_nguoi_nhan,so_dien_thoai,tinh_thanh,phuong_xa,dia_chi,mac_dinh) values (?,'Test','0900000000','City','Ward','456 Street',true)",customer);
        mvc.perform(get("/api/v1/staff/customers").param("q","Test Customer").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(jsonPath("$.total").value(1))
            .andExpect(jsonPath("$.items[0].dia_chi").value("456 Street, Ward, City"));
        mvc.perform(get("/api/v1/management/accounts").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(jsonPath(accountPath).value(org.hamcrest.Matchers.hasItem("456 Street, Ward, City")));
    }
    String editProduct(long quantity,long expected,String reason) {
        long category=db.number("select loai_san_pham_id from san_pham where id=?",product);
        return """
            {"fullName":"Edited drink","brand":"Test Brand","categoryId":%d,"active":true,
            "packageId":%d,"packaging":"LON","stock":%d,"expectedStock":%d,"stockReason":"%s"}
            """.formatted(category,pack,quantity,expected,reason);
    }
    @Test void adminStockEditsRecordHistoryAndRejectStaleOrNegativeValues() throws Exception {
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        mvc.perform(put("/api/v1/management/product-editor/"+product).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(editProduct(18,0,"Initial count")))
            .andExpect(status().isOk());
        assertEquals(18,stock());
        assertEquals(1,db.number("select count(*) from dieu_chinh_so_luong where san_pham_id=? and so_luong_truoc=0 and so_luong_sau=18 and nguoi_dieu_chinh_id=?",product,employee));
        assertEquals(1,db.number("select count(*) from bien_dong_so_luong where san_pham_id=? and loai='DIEU_CHINH'",product));
        mvc.perform(put("/api/v1/management/product-editor/"+product).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(editProduct(25,0,"Stale count")))
            .andExpect(status().isConflict());
        mvc.perform(put("/api/v1/management/product-editor/"+product).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(editProduct(-1,18,"Negative")))
            .andExpect(status().isBadRequest());
        mvc.perform(put("/api/v1/management/product-editor/"+product).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(editProduct(17,18,"")))
            .andExpect(status().isBadRequest());
        assertEquals(18,stock());
    }
    @Test void uploadAndProductImageArePublicButOnlyAdminCanModify() throws Exception {
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        byte[] png=Base64.getDecoder().decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=");
        var upload=mvc.perform(multipart("/api/v1/management/product-images").file(new org.springframework.mock.web.MockMultipartFile("file","drink.png","image/png",png)).header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andReturn();
        String url=new com.fasterxml.jackson.databind.ObjectMapper().readTree(upload.getResponse().getContentAsString()).get("url").asText();
        try {
            mvc.perform(get(url)).andExpect(status().isOk()).andExpect(content().bytes(png));
            String body=editProduct(0,0,"").replace("\"stockReason\":\"\"","\"stockReason\":\"\",\"imageUrl\":\""+url+"\"");
            mvc.perform(put("/api/v1/management/product-editor/"+product).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isOk());
            mvc.perform(get("/api/v1/catalog/products/"+product)).andExpect(status().isOk()).andExpect(jsonPath("$.images[0].duong_dan").value(url));
            mvc.perform(multipart("/api/v1/management/product-images").file(new org.springframework.mock.web.MockMultipartFile("file","bad.svg","image/svg+xml","<svg/>".getBytes())).header("Authorization","Bearer "+token)).andExpect(status().isBadRequest());
            auth.createAccount("staff@test.invalid","TestPass123!","NHAN_VIEN");
            String staffToken=auth.login("staff@test.invalid","TestPass123!").get("accessToken").toString();
            mvc.perform(put("/api/v1/management/product-editor/"+product).header("Authorization","Bearer "+staffToken).contentType(MediaType.APPLICATION_JSON).content(editProduct(50,0,"Forbidden"))).andExpect(status().isForbidden());
            mvc.perform(multipart("/api/v1/management/product-images").file(new org.springframework.mock.web.MockMultipartFile("file","drink.png","image/png",png)).header("Authorization","Bearer "+staffToken)).andExpect(status().isForbidden());
            assertEquals(0,stock());
        } finally { java.nio.file.Files.deleteIfExists(java.nio.file.Path.of(".tools/test-uploads",url.substring(url.lastIndexOf('/')+1))); }
    }
    @Test void freeShippingAndSelectedPaymentMethodMatchSavedOrder() throws Exception {
        mvc.perform(get("/api/v1/catalog/checkout-options")).andExpect(status().isOk())
            .andExpect(jsonPath("$.shippingFee").value(0))
            .andExpect(jsonPath("$.paymentMethods[0].code").value("COD"))
            .andExpect(jsonPath("$.paymentMethods[1].code").value("BANK_TRANSFER"));
        as(admin); receive(20); as(account);
        for(String method:List.of("COD","BANK_TRANSFER")) {
            carts.put(customer,pack,2);
            var quote=orders.quote(customer,List.of(pack),null);
            assertEquals(0,((BigDecimal)quote.get("shippingFee")).signum());
            assertEquals(quote.get("subtotal"),quote.get("total"));
            var order=(Map<?,?>)orders.checkout(customer,address,null,method,null,List.of(pack));
            assertEquals(0,((BigDecimal)order.get("phi_van_chuyen")).signum());
            assertEquals(0,((BigDecimal)quote.get("total")).compareTo((BigDecimal)order.get("tong_tien")));
            var payment=db.one("select * from thanh_toan where don_hang_id=?",order.get("id"));
            assertEquals(method,payment.get("phuong_thuc"));
            assertEquals("PENDING",payment.get("trang_thai"));
        }
    }
    String promotionBody(String code,String scope,String ids) {
        return """
            {"code":"%s","fullName":"Test promotion","description":"Test","discountType":"PERCENT","value":10,
             "minimumOrder":0,"startsAt":"%s","endsAt":"%s","scope":"%s","scopeIds":%s,"status":"ACTIVE"}
            """.formatted(code,java.time.OffsetDateTime.now().minusDays(1),java.time.OffsetDateTime.now().plusDays(7),scope,ids);
    }
    @Test void promotionEditorSavesScopesAtomicallyAndControlsCustomerDiscounts() throws Exception {
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        long category=db.number("select loai_san_pham_id from san_pham where id=?",product);
        String body=promotionBody("scope10","CATEGORY","["+category+"]");
        mvc.perform(post("/api/v1/management/promotion-editor").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk()).andExpect(jsonPath("$.ma_code").value("SCOPE10"));
        long id=db.id("select id from khuyen_mai where ma_code='SCOPE10'");
        mvc.perform(get("/api/v1/management/promotion-editor").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items[0].scope_ids[0]").value(category));
        mvc.perform(put("/api/v1/management/promotion-editor/"+id).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(promotionBody("CHANGED","CATEGORY","[999999999]")))
            .andExpect(status().isNotFound());
        assertEquals("SCOPE10",db.one("select ma_code from khuyen_mai where id=?",id).get("ma_code"));
        assertEquals(category,db.number("select loai_san_pham_id from pham_vi_khuyen_mai where khuyen_mai_id=?",id));
        mvc.perform(put("/api/v1/management/promotion-editor/"+id).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(body.replace("\"value\":10","\"value\":101")))
            .andExpect(status().isBadRequest());
        as(admin); receive(20); as(account); carts.put(customer,pack,2);
        var quote=orders.quote(customer,List.of(pack),"SCOPE10");
        assertEquals(0,((BigDecimal)quote.get("subtotal")).multiply(new BigDecimal("0.10")).compareTo((BigDecimal)quote.get("discount")));
        mvc.perform(patch("/api/v1/management/promotion-editor/"+id+"/status").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"INACTIVE\"}"))
            .andExpect(status().isOk());
        as(account); assertThrows(ApiException.class,()->orders.quote(customer,List.of(pack),"SCOPE10"));
        assertEquals(1,db.number("select count(*) from pham_vi_khuyen_mai where khuyen_mai_id=?",id));
    }
    @Test void supplierEditorPreservesPurchaseHistoryAndBlocksInactivePurchasing() throws Exception {
        receive(5);
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        String body="{\"fullName\":\"Managed supplier\",\"contactName\":\"Contact\",\"phone\":\"0900000000\",\"email\":\"supplier@test.invalid\",\"address\":\"123 Street\",\"supplierType\":\"DOANH_NGHIEP\",\"verificationStatus\":\"CHUA_XAC_MINH\",\"verificationNotes\":\"\",\"taxCode\":\"0123456789\",\"status\":\"HOP_TAC\"}";
        mvc.perform(put("/api/v1/management/supplier-editor/"+supplier).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk()).andExpect(jsonPath("$.nguoi_lien_he").value("Contact"));
        mvc.perform(patch("/api/v1/management/supplier-editor/"+supplier+"/status").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content("{\"status\":\"NGUNG_HOP_TAC\"}"))
            .andExpect(status().isOk());
        assertEquals(1,db.number("select count(*) from don_dat_hang_ncc where nha_cung_cap_id=?",supplier));
        as(admin); assertThrows(ApiException.class,()->purchases.create(new PurchaseController.Create(supplier,null,List.of(new PurchaseController.Line(pack,1,new BigDecimal("8000"))))));
    }
    @Test void employeesCannotUseSupplierAndPromotionEditors() throws Exception {
        auth.createAccount("staff@test.invalid","TestPass123!","NHAN_VIEN");
        String token=auth.login("staff@test.invalid","TestPass123!").get("accessToken").toString();
        mvc.perform(post("/api/v1/management/supplier-editor").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content("{\"fullName\":\"Forbidden supplier\",\"status\":\"HOP_TAC\"}"))
            .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/management/promotion-editor").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content(promotionBody("FORBIDDEN","ALL","[]")))
            .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/management/promotion-editor").header("Authorization","Bearer "+token)).andExpect(status().isForbidden());
    }
    @Test void receiptConfirmationIsIdempotentAndCreatesDebt() {
        long receipt=receive(20); assertEquals(20,stock());
        purchases.confirm(receipt); assertEquals(20,stock());
        assertEquals(1,db.number("select count(*) from lan_nhap_hang where trang_thai='CONFIRMED'"));
        assertEquals(0,new BigDecimal("160000").compareTo((BigDecimal)db.one("select so_tien_phai_tra from cong_no_ncc limit 1").get("so_tien_phai_tra")));
    }
    @Test void saleConfirmationAndCancellationAdjustStockExactlyOnce() {
        receive(20); long id=checkout(); assertEquals(20,stock());
        as(admin); orders.transition(id,"DANG_CHUAN_BI",null); assertEquals(18,stock());
        orders.transition(id,"DANG_CHUAN_BI",null); assertEquals(18,stock());
        assertNotNull(billing.invoice(id,null));
        orders.transition(id,"DA_HUY",null); assertEquals(20,stock());
        orders.transition(id,"DA_HUY",null); assertEquals(20,stock());
        assertEquals("CANCELLED",db.one("select trang_thai from hoa_don where don_hang_id=?",id).get("trang_thai"));
    }
    @Test void customerCannotCancelConfirmedOrderOrReadAnotherCustomersOrder() {
        receive(20); long id=checkout(); as(admin); orders.transition(id,"DANG_CHUAN_BI",null);
        as(account); assertThrows(ApiException.class,()->orders.transition(id,"DA_HUY",customer));
        assertThrows(ApiException.class,()->orders.detail(id,customer+9999));
    }
    @Test void codRequiresDeliveredOrder() {
        receive(20); long id=checkout(); as(admin); orders.transition(id,"DANG_CHUAN_BI",null);
        long payment=db.id("select id from thanh_toan where don_hang_id=?",id);
        assertThrows(ApiException.class,()->billing.received(payment,null));
        orders.transition(id,"DANG_GIAO",null); orders.transition(id,"DA_GIAO",null);
        billing.received(payment,null);
        assertEquals("SUCCESS",db.one("select trang_thai from thanh_toan where id=?",payment).get("trang_thai"));
    }
    @Test void failedLoginCounterIncrementsAndLocksAccount() {
        for(int i=0;i<5;i++) assertThrows(ApiException.class,()->auth.login("customer@test.invalid","WrongPassword!"));
        assertEquals("LOCKED",db.one("select trang_thai from tai_khoan where id=?",account).get("trang_thai"));
    }
    @Test void adminIncludesStaffPermissionsWhileStaffCannotApprovePurchase() {
        assertTrue(db.jdbc().queryForObject("select exists(select 1 from tai_khoan_vai_tro a join vai_tro_quyen rq on rq.vai_tro_id=a.vai_tro_id join quyen q on q.id=rq.quyen_id where a.tai_khoan_id=? and q.ma_quyen='IMPORT_RECEIVE')",Boolean.class,admin));
        assertTrue(db.jdbc().queryForObject("select exists(select 1 from tai_khoan_vai_tro a join vai_tro_quyen rq on rq.vai_tro_id=a.vai_tro_id join quyen q on q.id=rq.quyen_id where a.tai_khoan_id=? and q.ma_quyen='ORDER_UPDATE')",Boolean.class,admin));
        long staff=auth.createAccount("staff@test.invalid","TestPass123!","NHAN_VIEN");
        assertFalse(db.jdbc().queryForObject("select exists(select 1 from tai_khoan_vai_tro a join vai_tro_quyen rq on rq.vai_tro_id=a.vai_tro_id join quyen q on q.id=rq.quyen_id where a.tai_khoan_id=? and q.ma_quyen='IMPORT_APPROVE')",Boolean.class,staff));
    }
    @Test void receivesPartialDeliveriesWithoutDoubleCounting() {
        var po=(Map<?,?>)purchases.create(new PurchaseController.Create(supplier,null,List.of(new PurchaseController.Line(pack,10,new BigDecimal("8000")))));
        long id=((Number)po.get("id")).longValue(); purchases.decide(id,new PurchaseController.Decision("DA_DUYET",null));
        long line=db.id("select id from chi_tiet_don_ncc where don_ncc_id=?",id);
        for(int quantity:List.of(4,6)) {
            var receipt=(Map<?,?>)purchases.receipt(id,new PurchaseController.Receive(List.of(new PurchaseController.ReceiptLine(line,quantity,new BigDecimal("8000")))));
            long r=((Number)receipt.get("id")).longValue(); purchases.confirm(r); purchases.confirm(r);
            assertEquals(quantity==4?"DA_NHAN_MOT_PHAN":"DA_NHAN_DU",db.one("select trang_thai from don_dat_hang_ncc where id=?",id).get("trang_thai"));
        }
        assertEquals(10,stock());
        assertEquals(2,db.number("select count(*) from cong_no_ncc c join lan_nhap_hang r on r.id=c.lan_nhap_id where r.don_ncc_id=?",id));
        assertEquals(0,new BigDecimal("80000").compareTo(Db.money(db.one("select sum(c.so_tien_phai_tra) as so_tien_phai_tra from cong_no_ncc c join lan_nhap_hang r on r.id=c.lan_nhap_id where r.don_ncc_id=?",id),"so_tien_phai_tra")));
    }
    @Test void couponIsRecordedAtConfirmationAndReversedOnCancellation() {
        receive(20);
        long promo=db.id("insert into khuyen_mai(ma_code,ten,loai_giam,gia_tri_giam,bat_dau,ket_thuc,gioi_han_su_dung) values ('TEST10','Test','PERCENT',10,now()-interval '1 day',now()+interval '1 day',1) returning id");
        as(account); carts.put(customer,pack,2);
        long id=((Number)((Map<?,?>)orders.checkout(customer,address,null,"COD","TEST10")).get("id")).longValue();
        assertEquals(0,db.number("select count(*) from su_dung_khuyen_mai where khuyen_mai_id=?",promo));
        as(admin); orders.transition(id,"DANG_CHUAN_BI",null);
        assertEquals(1,db.number("select count(*) from su_dung_khuyen_mai where khuyen_mai_id=? and trang_thai='APPLIED'",promo));
        orders.transition(id,"DA_HUY",null);
        assertEquals("REVERSED",db.one("select trang_thai from su_dung_khuyen_mai where khuyen_mai_id=?",promo).get("trang_thai"));
    }
    @Test void httpEnforcesAuthenticationRolesOwnershipAndRevocation() throws Exception {
        SecurityContextHolder.clearContext();
        mvc.perform(options("/api/v1/cart").header("Origin","http://localhost:5173").header("Access-Control-Request-Method","GET").header("Access-Control-Request-Headers","authorization"))
            .andExpect(status().isOk()).andExpect(header().string("Access-Control-Allow-Origin","http://localhost:5173"));
        mvc.perform(options("/api/v1/cart").header("Origin","https://untrusted.invalid").header("Access-Control-Request-Method","GET"))
            .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/cart")).andExpect(status().isUnauthorized());
        String token=auth.login("customer@test.invalid","TestPass123!").get("accessToken").toString();
        mvc.perform(get("/api/v1/management/accounts").header("Authorization","Bearer "+token)).andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/auth/me").header("Authorization","Bearer "+token)).andExpect(status().isOk()).andExpect(jsonPath("$.account.id").value(account));
        mvc.perform(put("/api/v1/cart/items/"+pack).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content("{\"quantity\":0}")).andExpect(status().isBadRequest());
        mvc.perform(put("/api/v1/me/addresses/9999999").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content("{\"recipient\":\"A\",\"phone\":\"0900000000\",\"province\":\"HCM\",\"street\":\"A\",\"isDefault\":true}")).andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/auth/logout").header("Authorization","Bearer "+token)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/auth/me").header("Authorization","Bearer "+token)).andExpect(status().isUnauthorized());
    }

    @Test void revisedCatalogAndReportsExecuteAgainstNewSchema() throws Exception {
        receive(20);
        mvc.perform(get("/api/v1/catalog/products").param("sort","priceAsc"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items[0].gia_tu").exists())
            .andExpect(jsonPath("$.items[0].gia_von").doesNotExist());
        mvc.perform(get("/api/v1/catalog/products/"+product)).andExpect(status().isOk())
            .andExpect(jsonPath("$.packages[0].don_vi_tinh").value("LON")).andExpect(jsonPath("$.packages[0].gia_von").doesNotExist());
        for(String path:List.of("/catalog/categories","/catalog/brands","/catalog/promotions","/catalog/products/"+product+"/reviews"))
            mvc.perform(get("/api/v1"+path)).andExpect(status().isOk());
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        for(String path:List.of("/staff/reports/stock","/staff/reports/purchases?from=2020-01-01&to=2021-01-01",
            "/management/reports/revenue?from=2020-01-01&to=2021-01-01","/management/reports/order-status",
            "/management/reports/promotions","/management/reports/expiring-documents","/debts"))
            mvc.perform(get("/api/v1"+path).header("Authorization","Bearer "+token)).andExpect(status().isOk());
        assertEquals(1,db.number("select count(*) from information_schema.tables where table_schema='public' and table_name='password_reset_challenge'"));
    }
    @Test void joinedRolePermissionsAndAssignmentsRevokeSessions() throws Exception {
        String customerToken=auth.login("customer@test.invalid","TestPass123!").get("accessToken").toString();
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        mvc.perform(get("/api/v1/management/roles").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andExpect(jsonPath("$.grants").isArray());
        long role=db.id("select id from vai_tro where ma_vai_tro='NHAN_VIEN'");
        long permission=db.id("select id from quyen where ma_quyen='REPORT_STOCK'");
        mvc.perform(put("/api/v1/management/roles/"+role+"/permissions").header("Authorization","Bearer "+token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"permissionIds\":["+permission+"]}"))
            .andExpect(status().isOk());
        db.jdbc().update("insert into nhan_vien(tai_khoan_id,ma_nhan_vien,ho_ten) values (?,'NV-CUSTOMER','Customer Employee')",account);
        mvc.perform(put("/api/v1/management/accounts/"+account+"/roles/"+role).header("Authorization","Bearer "+token)).andExpect(status().isOk());
        assertEquals(2,db.number("select count(*) from tai_khoan_vai_tro where tai_khoan_id=?",account));
        assertTrue(((List<?>)auth.profile(account).get("permissions")).contains("REPORT_STOCK"));
        assertEquals(1,db.number("select count(*) from phien_xac_thuc where tai_khoan_id=? and da_thu_hoi",account));
        org.springframework.security.test.context.TestSecurityContextHolder.clearContext();
        mvc.perform(get("/api/v1/auth/me").header("Authorization","Bearer "+customerToken)).andExpect(status().isUnauthorized());
    }
    @Test void supplierPaymentReducesDebt() {
        receive(20);
        long debt=db.id("select id from cong_no_ncc limit 1");
        purchases.payDebt(debt,new PurchaseController.DebtPayment(new BigDecimal("60000"),"BANK_TRANSFER","TEST-REF"));
        assertEquals(0,new BigDecimal("100000").compareTo(Db.money(db.one("select * from cong_no_ncc where id=?",debt),"so_tien_con_no")));
        assertThrows(ApiException.class,()->purchases.payDebt(debt,new PurchaseController.DebtPayment(new BigDecimal("100001"),"BANK_TRANSFER",null)));
    }
    @Test void revisedManagementAndReviewFieldsWork() throws Exception {
        String token=auth.login("admin@test.invalid","TestPass123!").get("accessToken").toString();
        mvc.perform(post("/api/v1/management/products").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"sku\":\"NEW-SKU\",\"loai_san_pham_id\":1,\"thuong_hieu_id\":1,\"ten\":\"New drink\"}"))
            .andExpect(status().isCreated()).andExpect(jsonPath("$.sku").value("NEW-SKU"));
        as(admin); receive(20); long order=checkout(); as(admin);
        orders.transition(order,"DANG_CHUAN_BI",null); orders.transition(order,"DANG_GIAO",null); orders.transition(order,"DA_GIAO",null);
        long line=db.id("select id from chi_tiet_don_hang where don_hang_id=?",order);
        String customerToken=auth.login("customer@test.invalid","TestPass123!").get("accessToken").toString();
        mvc.perform(put("/api/v1/me/profile").header("Authorization","Bearer "+customerToken).contentType(MediaType.APPLICATION_JSON)
            .content("{\"fullName\":\"Customer New\",\"phone\":\"0900000000\"}"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.dien_thoai").value("0900000000"));
        mvc.perform(post("/api/v1/me/reviews").header("Authorization","Bearer "+customerToken).contentType(MediaType.APPLICATION_JSON)
            .content("{\"orderLineId\":"+line+",\"rating\":5,\"comment\":\"Good\"}"))
            .andExpect(status().isOk());
        long review=db.id("select id from danh_gia_san_pham where chi_tiet_don_hang_id=?",line);
        mvc.perform(patch("/api/v1/staff/reviews/"+review).header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON).content("{\"visible\":true}"))
            .andExpect(status().isOk());
        mvc.perform(get("/api/v1/catalog/products/"+product+"/reviews"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items[0].noi_dung").value("Good"));
    }
    @Test void paidInvoiceUsesNewOrderStates() {
        receive(20); long id=checkout(); as(admin);
        orders.transition(id,"DANG_CHUAN_BI",null); orders.transition(id,"DANG_GIAO",null); orders.transition(id,"DA_GIAO",null);
        long payment=db.id("select id from thanh_toan where don_hang_id=?",id);
        billing.received(payment,null);
        assertEquals("PAID",db.one("select trang_thai from hoa_don where don_hang_id=?",id).get("trang_thai"));
    }

    @Test void packageQuantityUsesItsConversionFactorAndOwnPrice() {
        receive(20);
        long sixPack=db.id("select id from quy_cach_san_pham where san_pham_id=? and he_so_quy_doi=6",product);
        as(account); carts.put(customer,sixPack,2);
        long id=((Number)((Map<?,?>)orders.checkout(customer,address,null,"COD",null)).get("id")).longValue();
        var line=db.one("select * from chi_tiet_don_hang where don_hang_id=?",id);
        assertEquals(6,Db.n(line,"he_so_quy_doi"));
        assertEquals(0,new BigDecimal("60000").compareTo(Db.money(line,"don_gia")));
        as(admin); orders.transition(id,"DANG_CHUAN_BI",null);
        assertEquals(8,stock());
    }
    @Test void receiptGroupsPackagesBeforeAveragingAndAutomaticallyAddsTwentyFivePercent() {
        receive(50);
        var po=(Map<?,?>)purchases.create(new PurchaseController.Create(supplier,null,List.of(
            new PurchaseController.Line(pack,12,new BigDecimal("9000")),
            new PurchaseController.Line(null,15,new BigDecimal("54000"),product,"LOC",6))));
        long purchase=((Number)po.get("id")).longValue();
        var lines=db.rows("select d.id,d.he_so_quy_doi from chi_tiet_don_ncc d where d.don_ncc_id=? order by d.he_so_quy_doi",purchase);
        var draft=(Map<?,?>)purchases.receipt(purchase,new PurchaseController.Receive(List.of(
            new PurchaseController.ReceiptLine(Db.n(lines.get(0),"id"),10,new BigDecimal("9000"),2,"Broken"),
            new PurchaseController.ReceiptLine(Db.n(lines.get(1),"id"),15,new BigDecimal("54000")))));
        long receipt=((Number)draft.get("id")).longValue();
        assertEquals(50,stock());
        purchases.confirm(receipt); purchases.confirm(receipt);
        assertEquals(150,stock());
        var primary=db.one("select gia_von,gia_ban from quy_cach_san_pham where id=?",pack);
        assertEquals(0,new BigDecimal("8666.67").compareTo(Db.money(primary,"gia_von")));
        assertEquals(0,new BigDecimal("11000").compareTo(Db.money(primary,"gia_ban")));
        assertEquals(900000,db.number("select so_tien_phai_tra from cong_no_ncc where lan_nhap_id=?",receipt));
    }
    @Test void damagedDeliveryExcludesRejectedGoodsFromStockAndDebt() {
        var po=(Map<?,?>)purchases.create(new PurchaseController.Create(supplier,null,List.of(new PurchaseController.Line(pack,10,new BigDecimal("10000")))));
        long purchase=((Number)po.get("id")).longValue(); purchases.decide(purchase,new PurchaseController.Decision("DA_DUYET",null));
        long line=db.id("select id from chi_tiet_don_ncc where don_ncc_id=?",purchase);
        var draft=(Map<?,?>)purchases.receipt(purchase,new PurchaseController.Receive(List.of(new PurchaseController.ReceiptLine(line,8,new BigDecimal("10000"),2,"Broken"))));
        long receipt=((Number)draft.get("id")).longValue();purchases.confirm(receipt);
        assertEquals(8,stock());
        assertEquals(0,new BigDecimal("80000").compareTo(Db.money(db.one("select * from cong_no_ncc where lan_nhap_id=?",receipt),"so_tien_con_no")));
        purchases.confirm(receipt);
        @SuppressWarnings("unchecked") var history=(Map<String,Object>)supplierReturns.list(0,100);
        @SuppressWarnings("unchecked") var returned=(List<Map<String,Object>>)history.get("items");
        var rejection=returned.stream().filter(row->"RECEIPT_REJECTION".equals(row.get("source")) && Db.n(row,"lan_nhap_id")==receipt).toList();
        assertEquals(1,rejection.size());
        assertEquals(0,new BigDecimal("20000").compareTo(Db.money(rejection.getFirst(),"tong_tien")));
        assertEquals(0,Db.money(rejection.getFirst(),"so_tien_giam_no").signum());
        assertNull(db.jdbc().queryForObject("select to_regclass('public.phieu_tra_ncc')",String.class));
        assertEquals(8,stock());
        assertEquals(0,new BigDecimal("10000").compareTo(Db.money(db.one("select gia_von from quy_cach_san_pham where id=?",pack),"gia_von")));
        assertEquals(8,stock());
        assertEquals(0,db.number("select so_luong_dat-(select sum(c.so_luong_thuc_nhan+c.so_luong_loai) from chi_tiet_lan_nhap c join lan_nhap_hang r on r.id=c.lan_nhap_id where c.ct_don_ncc_id=d.id and r.trang_thai='CONFIRMED') from chi_tiet_don_ncc d where d.id=?",line));
        assertThrows(ApiException.class,()->purchases.receipt(purchase,new PurchaseController.Receive(List.of(new PurchaseController.ReceiptLine(line,2,new BigDecimal("10000"))))));
        assertEquals("DA_NHAN_DU",db.one("select trang_thai from don_dat_hang_ncc where id=?",purchase).get("trang_thai"));
    }
    @Test void entirelyRejectedDeliverySettlesThePurchaseWithoutStockOrPayable() {
        var po=(Map<?,?>)purchases.create(new PurchaseController.Create(supplier,null,List.of(new PurchaseController.Line(pack,10,new BigDecimal("8000")))));
        long purchase=((Number)po.get("id")).longValue();purchases.decide(purchase,new PurchaseController.Decision("DA_DUYET",null));
        long line=db.id("select id from chi_tiet_don_ncc where don_ncc_id=?",purchase);
        var draft=(Map<?,?>)purchases.receipt(purchase,new PurchaseController.Receive(List.of(new PurchaseController.ReceiptLine(line,0,new BigDecimal("8000"),10,"Expired"))));
        long receipt=((Number)draft.get("id")).longValue();purchases.confirm(receipt);assertEquals(0,stock());
        assertEquals("DA_NHAN_DU",db.one("select trang_thai from don_dat_hang_ncc where id=?",purchase).get("trang_thai"));
        assertEquals("DA_TRA",db.one("select trang_thai from cong_no_ncc where lan_nhap_id=?",receipt).get("trang_thai"));
    }
    @Test void importCaseFactorCountsOnlyAcceptedCasesInStockAndDebt() {
        var po=(Map<?,?>)purchases.create(new PurchaseController.Create(supplier,null,List.of(new PurchaseController.Line(null,2,new BigDecimal("240000"),product,"THUNG",48))));
        long purchase=((Number)po.get("id")).longValue();purchases.decide(purchase,new PurchaseController.Decision("DA_DUYET",null));
        var line=db.one("select * from chi_tiet_don_ncc where don_ncc_id=?",purchase);
        assertEquals(48,Db.n(line,"he_so_quy_doi"));assertEquals(false,db.one("select dang_ban from quy_cach_san_pham where id=?",line.get("quy_cach_id")).get("dang_ban"));
        var draft=(Map<?,?>)purchases.receipt(purchase,new PurchaseController.Receive(List.of(new PurchaseController.ReceiptLine(Db.n(line,"id"),1,new BigDecimal("240000"),1,"Damaged case"))));
        long receipt=((Number)draft.get("id")).longValue();purchases.confirm(receipt);purchases.confirm(receipt);
        assertEquals(48,stock());assertEquals(240000,db.number("select so_tien_con_no from cong_no_ncc where lan_nhap_id=?",receipt));
        assertEquals("DA_NHAN_DU",db.one("select trang_thai from don_dat_hang_ncc where id=?",purchase).get("trang_thai"));
        assertEquals(0,Db.money(db.one("select gia_von from quy_cach_san_pham where id=?",pack),"gia_von").compareTo(new BigDecimal("5000")));
    }
    @Test void productProfitUsesSnapshotCostAndExcludesUnsoldPurchases() {
        receive(10);long order=checkout();as(admin);orders.transition(order,"DANG_CHUAN_BI",null);orders.transition(order,"DANG_GIAO",null);orders.transition(order,"DA_GIAO",null);
        @SuppressWarnings("unchecked") var report=(List<Map<String,Object>>)productFinance.products(null,null);
        var row=report.stream().filter(p->Db.n(p,"product_id")==product).findFirst().orElseThrow();
        assertEquals(80000,Db.n(row,"import_amount"));assertEquals(16000,Db.n(row,"cost_of_goods"));
        assertEquals(2,Db.n(row,"sold_qty"));assertEquals(8,Db.n(row,"current_stock"));
        assertEquals(0,Db.money(row,"net_sales").subtract(new BigDecimal("16000")).compareTo(Db.money(row,"gross_profit")));
    }
    @Test void employeeCannotCreateSupplierOrderUnderNewSeedPermissions() throws Exception {
        auth.createAccount("staff@test.invalid","TestPass123!","NHAN_VIEN");
        String token=auth.login("staff@test.invalid","TestPass123!").get("accessToken").toString();
        org.springframework.security.test.context.TestSecurityContextHolder.clearContext();
        mvc.perform(post("/api/v1/purchases").header("Authorization","Bearer "+token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"supplierId\":"+supplier+",\"items\":[{\"packageId\":"+pack+",\"quantity\":1,\"unitCost\":8000}]}"))
            .andExpect(status().isForbidden());
    }
}
