import http from "k6/http"
import { check, sleep } from "k6"
import { __ENV } from "k6/env" // Declare the __ENV variable

export const options = {
  stages: [
    { duration: "2m", target: 10 }, // Ramp up
    { duration: "5m", target: 10 }, // Stay at 10 users
    { duration: "2m", target: 20 }, // Ramp up to 20 users
    { duration: "5m", target: 20 }, // Stay at 20 users
    { duration: "2m", target: 0 }, // Ramp down
  ],
  thresholds: {
    http_req_duration: ["p(95)<500"], // 95% of requests must complete below 500ms
    http_req_failed: ["rate<0.1"], // Error rate must be below 10%
  },
}

export default function () {
  // Test frontend
  const frontendResponse = http.get(`${__ENV.FRONTEND_URL || "http://localhost"}`)
  check(frontendResponse, {
    "frontend status is 200": (r) => r.status === 200,
    "frontend response time < 500ms": (r) => r.timings.duration < 500,
  })

  // Test backend API
  const backendResponse = http.get(`${__ENV.BACKEND_URL || "http://localhost"}/wp-json/wp/v2/posts`)
  check(backendResponse, {
    "backend status is 200": (r) => r.status === 200,
    "backend response time < 1000ms": (r) => r.timings.duration < 1000,
  })

  sleep(1)
}
