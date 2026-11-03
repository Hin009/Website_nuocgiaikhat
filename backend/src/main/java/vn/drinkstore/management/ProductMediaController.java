package vn.drinkstore.management;

import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.*;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import vn.drinkstore.common.ApiException;

@RestController
@RequestMapping("/api/v1")
public class ProductMediaController {
    private final Path directory;
    public ProductMediaController(@Value("${app.upload-dir:./uploads}") String directory) {
        this.directory=Path.of(directory).toAbsolutePath().normalize();
    }
    @PostMapping(value="/management/product-images",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("@access.admin() and @access.has('PRODUCT_MANAGE')")
    public Object upload(@RequestParam("file") MultipartFile file) throws IOException {
        if(file.isEmpty() || file.getSize()>5*1024*1024) throw ApiException.bad("Ảnh phải có dung lượng từ 1 byte đến 5 MB");
        byte[] bytes=file.getBytes();
        String extension;
        if(bytes.length>=8 && Arrays.equals(Arrays.copyOf(bytes,8),new byte[]{(byte)137,80,78,71,13,10,26,10})) extension="png";
        else if(bytes.length>=3 && (bytes[0]&255)==255 && (bytes[1]&255)==216 && (bytes[2]&255)==255) extension="jpg";
        else if(bytes.length>=12 && new String(bytes,0,4,java.nio.charset.StandardCharsets.US_ASCII).equals("RIFF") && new String(bytes,8,4,java.nio.charset.StandardCharsets.US_ASCII).equals("WEBP")) extension="webp";
        else throw ApiException.bad("Chỉ nhận ảnh JPG, PNG hoặc WebP");
        Files.createDirectories(directory);
        String name=UUID.randomUUID()+"."+extension;
        Files.write(directory.resolve(name),bytes,StandardOpenOption.CREATE_NEW);
        return Map.of("url","/api/v1/media/products/"+name);
    }
    @GetMapping("/media/products/{name}")
    public ResponseEntity<Resource> image(@PathVariable String name) {
        if(!name.matches("[a-f0-9-]{36}\\.(png|jpg|webp)")) throw ApiException.missing();
        Path path=directory.resolve(name);
        if(!Files.isRegularFile(path)) throw ApiException.missing();
        MediaType type=name.endsWith(".png")?MediaType.IMAGE_PNG:name.endsWith(".jpg")?MediaType.IMAGE_JPEG:MediaType.parseMediaType("image/webp");
        return ResponseEntity.ok().contentType(type).header("X-Content-Type-Options","nosniff")
            .cacheControl(CacheControl.maxAge(java.time.Duration.ofDays(1))).body(new FileSystemResource(path));
    }
}
