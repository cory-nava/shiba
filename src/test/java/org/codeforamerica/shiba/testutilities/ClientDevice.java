package org.codeforamerica.shiba.testutilities;

import org.codeforamerica.shiba.pages.DeviceDetector;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;

@TestConfiguration
public class ClientDevice {

	@Bean
	public DeviceDetector.DeviceInfo deviceInfo() {
		return new DeviceDetector.DeviceInfo("mobile", "ANDROID");
	}

}
