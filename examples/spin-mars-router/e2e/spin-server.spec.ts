import { expect, test } from "@playwright/test";

test("GET / returns top route", async ({ request }) => {
  const response = await request.get("/");
  expect(response.status()).toBe(200);
  await expect(response.text()).resolves.toContain("mars-router: top");
});

test("GET /users/:id resolves path param", async ({ request }) => {
  const response = await request.get("/users/42");
  expect(response.status()).toBe(200);
  await expect(response.text()).resolves.toContain("mars-router: user=42");
});

test("GET /files/* resolves wildcard route", async ({ request }) => {
  const response = await request.get("/files/a/b/c");
  expect(response.status()).toBe(200);
  await expect(response.text()).resolves.toContain(
    "mars-router: wildcard=/files/a/b/c",
  );
});

test("GET unknown path returns 404", async ({ request }) => {
  const response = await request.get("/nope");
  expect(response.status()).toBe(404);
  await expect(response.text()).resolves.toContain("not found: /nope");
});
