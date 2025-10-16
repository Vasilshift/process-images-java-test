package com.tenderizz.test_endpoint;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
@CrossOrigin(origins = {"https://tenderizz.com", "http://localhost:3000"})
public class UploadController {
    @PostMapping("/process-all-images")
    public ResponseEntity<String> handleUpload(@RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok("Received file: " + file.getOriginalFilename());
    }

    @GetMapping("/ping")
    public String ping() {
        return "pong";
    }
}
