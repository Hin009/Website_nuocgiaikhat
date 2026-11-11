package vn.drinkstore.billing;

import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import vn.drinkstore.common.ApiException;

public class MomoClientTest {
    @Test void createSignatureMatchesIndependentPythonHmacFixture() {
        var data=new HashMap<String,Object>();
        data.put("requestType","captureWallet"); data.put("requestId","request-1");
        data.put("redirectUrl","http://localhost:5173/return"); data.put("partnerCode","TEST");
        data.put("orderInfo","WATERBUS"); data.put("orderId","order-1");
        data.put("ipnUrl","https://example.invalid/ipn"); data.put("extraData","");
        data.put("amount",10000); data.put("accessKey","access");
        assertEquals("7bd5ca51c518a31817552043d33f60961e0f66e92c21042bac9faf2f90fcc035",MomoClient.sign("secret",data,MomoClient.CREATE_FIELDS));
        assertEquals("https://test-payment.momo.vn/v2/gateway/api/create",MomoClient.CREATE_URL);
    }
    static MomoProperties config() {
        var c=new MomoProperties(); c.enabled=true; c.partnerCode="TEST_PARTNER"; c.accessKey="fixture-access";
        c.secretKey="fixture-secret"; c.ipnUrl="https://example.invalid/api/v1/payments/momo/ipn";
        c.redirectUrl="http://localhost:5173/payments/momo/return"; return c;
    }
    public static Map<String,Object> notification(String order,String request,Object amount,int result) {
        var p=new HashMap<String,Object>();
        p.put("partnerCode","TEST_PARTNER"); p.put("orderId",order); p.put("requestId",request); p.put("amount",amount);
        p.put("extraData",""); p.put("message",result==0?"Successful.":"Failed."); p.put("orderInfo","WATERBUS fixture");
        p.put("orderType","momo_wallet"); p.put("payType","qr"); p.put("responseTime",1721720663942L);
        p.put("resultCode",result); p.put("transId",4088878653L); return p;
    }
    @Test void authenticatesIpnAndRejectsTamperingOrMissingFields() {
        var config=config(); var client=new MomoClient(config,new ObjectMapper());
        var p=notification("order-1","request-1",10000,0); sign(config,p);
        assertDoesNotThrow(()->client.verify(p));
        p.put("amount",10001); assertThrows(ApiException.class,()->client.verify(p));
        p.remove("amount"); assertThrows(ApiException.class,()->client.verify(p));
    }
    public static void sign(MomoProperties config,Map<String,Object> p) {
        var signed=new HashMap<>(p); signed.put("accessKey",config.accessKey);
        p.put("signature",MomoClient.sign(config.secretKey,signed,MomoClient.IPN_FIELDS));
    }
    @Test void cannotEnableProductionOrUseMissingCredentials() {
        var c=config(); assertTrue(c.ready()); c.environment="production"; assertFalse(c.ready());
        assertThrows(ApiException.class,c::requireReady); c.environment="sandbox"; c.secretKey=""; assertFalse(c.ready());
    }
}
