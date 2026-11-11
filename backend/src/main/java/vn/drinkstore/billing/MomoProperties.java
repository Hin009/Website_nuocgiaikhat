package vn.drinkstore.billing;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import vn.drinkstore.common.ApiException;

@Component
@ConfigurationProperties(prefix="app.momo")
public class MomoProperties {
    public boolean enabled;
    public String environment="sandbox", partnerCode="", accessKey="", secretKey="", redirectUrl="", ipnUrl="";
    public void setEnabled(boolean v) { enabled=v; }
    public void setEnvironment(String v) { environment=v; }
    public void setPartnerCode(String v) { partnerCode=v; }
    public void setAccessKey(String v) { accessKey=v; }
    public void setSecretKey(String v) { secretKey=v; }
    public void setRedirectUrl(String v) { redirectUrl=v; }
    public void setIpnUrl(String v) { ipnUrl=v; }
    public boolean ready() {
        return enabled && "sandbox".equals(environment) && !partnerCode.isBlank() && !accessKey.isBlank()
            && !secretKey.isBlank() && redirectUrl.startsWith("http") && ipnUrl.startsWith("https://");
    }
    public void requireReady() {
        if(!ready()) throw ApiException.bad("MoMo Sandbox chưa được cấu hình đầy đủ. Vui lòng liên hệ cửa hàng hoặc chọn COD.");
    }
}
