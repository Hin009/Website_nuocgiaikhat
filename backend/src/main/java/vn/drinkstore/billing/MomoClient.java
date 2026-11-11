package vn.drinkstore.billing;

import java.net.URI;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.*;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;
import vn.drinkstore.common.ApiException;

@Component
public class MomoClient {
    public static final String CREATE_URL="https://test-payment.momo.vn/v2/gateway/api/create";
    static final List<String> CREATE_FIELDS=List.of("accessKey","amount","extraData","ipnUrl","orderId","orderInfo","partnerCode","redirectUrl","requestId","requestType");
    static final List<String> IPN_FIELDS=List.of("accessKey","amount","extraData","message","orderId","orderInfo","orderType","partnerCode","payType","requestId","responseTime","resultCode","transId");
    private final MomoProperties config;
    private final ObjectMapper json;
    private final HttpClient http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).followRedirects(HttpClient.Redirect.NEVER).build();
    public MomoClient(MomoProperties config,ObjectMapper json) { this.config=config; this.json=json; }
    static String sign(String secret,Map<String,?> data,List<String> fields) {
        try {
            var values=new ArrayList<String>();
            for(String key:fields) {
                if(data.get(key)==null) throw ApiException.bad("Thiếu trường MoMo: "+key);
                values.add(key+"="+data.get(key));
            }
            Mac mac=Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8),"HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(String.join("&",values).getBytes(StandardCharsets.UTF_8)));
        } catch(ApiException e) { throw e; } catch(Exception e) { throw new IllegalStateException("Cannot sign MoMo request",e); }
    }
    public void verify(Map<String,Object> payload) {
        config.requireReady();
        var data=new HashMap<String,Object>(payload); data.put("accessKey",config.accessKey);
        String expected=sign(config.secretKey,data,IPN_FIELDS);
        String actual=Objects.toString(payload.get("signature"),"");
        if(!MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8),actual.getBytes(StandardCharsets.UTF_8))
            || !config.partnerCode.equals(payload.get("partnerCode"))) throw ApiException.bad("IPN MoMo không hợp lệ");
    }
    public Map<String,Object> create(Map<String,Object> attempt) {
        config.requireReady();
        var data=new HashMap<String,Object>();
        data.put("partnerCode",config.partnerCode); data.put("accessKey",config.accessKey);
        data.put("requestId",attempt.get("request_id")); data.put("orderId",attempt.get("momo_order_id"));
        data.put("amount",attempt.get("amount")); data.put("orderInfo",attempt.get("order_info"));
        data.put("redirectUrl",attempt.get("redirect_url")); data.put("ipnUrl",attempt.get("ipn_url"));
        data.put("extraData",""); data.put("requestType","captureWallet");
        data.put("signature",sign(config.secretKey,data,CREATE_FIELDS));
        data.remove("accessKey"); data.put("lang","vi"); data.put("autoCapture",true);
        try {
            var request=HttpRequest.newBuilder(URI.create(CREATE_URL)).timeout(Duration.ofSeconds(25))
                .header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(data))).build();
            var response=http.send(request,HttpResponse.BodyHandlers.ofString());
            if(response.statusCode()!=200) throw new IllegalStateException("MoMo HTTP "+response.statusCode());
            var result=json.readValue(response.body(),new com.fasterxml.jackson.core.type.TypeReference<Map<String,Object>>() {});
            if(!config.partnerCode.equals(result.get("partnerCode")) || !attempt.get("momo_order_id").equals(result.get("orderId"))
                || !attempt.get("request_id").equals(result.get("requestId"))) throw new IllegalStateException("MoMo response mismatch");
            if(Integer.valueOf(0).equals(result.get("resultCode")) && (result.get("amount")==null
                || new java.math.BigDecimal(result.get("amount").toString()).compareTo(new java.math.BigDecimal(attempt.get("amount").toString()))!=0))
                throw new IllegalStateException("MoMo response amount mismatch");
            return result;
        } catch(InterruptedException e) { Thread.currentThread().interrupt(); throw new IllegalStateException("MoMo interrupted",e); }
        catch(Exception e) { throw new IllegalStateException("Chưa nhận được kết quả tạo thanh toán MoMo. Thử lại với cùng giao dịch.",e); }
    }
}
