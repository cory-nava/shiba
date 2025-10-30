package org.codeforamerica.shiba.pages;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * Simple User-Agent based device detector to replace discontinued Spring Mobile.
 * Detects device type (mobile, tablet, desktop) and platform from User-Agent string.
 */
@Component
@Slf4j
public class DeviceDetector {

  public DeviceInfo detectDevice(String userAgent) {
    if (userAgent == null || userAgent.isEmpty()) {
      log.debug("Empty user agent, returning unknown device");
      return new DeviceInfo("unknown", "unknown");
    }

    String deviceType = detectDeviceType(userAgent);
    String platform = detectPlatform(userAgent);

    log.debug("Detected device - type: {}, platform: {}", deviceType, platform);
    return new DeviceInfo(deviceType, platform);
  }

  private String detectDeviceType(String userAgent) {
    String lowerUserAgent = userAgent.toLowerCase();

    // Check for tablets first (they often contain "mobile" in their user agent)
    if (lowerUserAgent.contains("ipad") ||
        lowerUserAgent.contains("tablet") ||
        lowerUserAgent.contains("kindle") ||
        (lowerUserAgent.contains("android") && !lowerUserAgent.contains("mobile"))) {
      return "tablet";
    }

    // Check for mobile devices
    if (lowerUserAgent.contains("mobile") ||
        lowerUserAgent.contains("iphone") ||
        lowerUserAgent.contains("ipod") ||
        lowerUserAgent.contains("android") ||
        lowerUserAgent.contains("blackberry") ||
        lowerUserAgent.contains("windows phone") ||
        lowerUserAgent.contains("opera mini") ||
        lowerUserAgent.contains("webos")) {
      return "mobile";
    }

    // Default to desktop
    return "desktop";
  }

  private String detectPlatform(String userAgent) {
    String lowerUserAgent = userAgent.toLowerCase();

    if (lowerUserAgent.contains("iphone") || lowerUserAgent.contains("ipad") || lowerUserAgent.contains("ipod")) {
      return "IOS";
    }
    if (lowerUserAgent.contains("android")) {
      return "ANDROID";
    }
    if (lowerUserAgent.contains("windows")) {
      return "WINDOWS";
    }
    if (lowerUserAgent.contains("mac os")) {
      return "MAC";
    }
    if (lowerUserAgent.contains("linux")) {
      return "LINUX";
    }

    return "UNKNOWN";
  }

  /**
   * Simple data class to hold device information.
   */
  public static class DeviceInfo {
    private final String deviceType;
    private final String platform;

    public DeviceInfo(String deviceType, String platform) {
      this.deviceType = deviceType;
      this.platform = platform;
    }

    public String getDeviceType() {
      return deviceType;
    }

    public String getPlatform() {
      return platform;
    }
  }
}
