import { test, expect } from '@playwright/test';

test.describe('Admin - News CRUD (stubbed)', () => {
  test.beforeEach(async ({ page }) => {
    // Sign-in stub (cookie/localStorage if app expects)
    await page.addInitScript(() => {
      localStorage.setItem('admin_auth', JSON.stringify({ token: 'test', user: { id: '1', email: 'admin@test' } }));
    });
  });

  test('list page renders and matches snapshot', async ({ page }) => {
    // Stub API
    await page.route('**/api/v1/admin/news*', async route => {
      const json = [
        { id: '1', title: 'Вийшло оновлення Sweezy', source: 'Sweezy', status: 'published', created_at: '2025-11-10' },
        { id: '2', title: 'Untitled', source: 'RSS', status: 'draft', created_at: '2025-11-10' }
      ];
      await route.fulfill({ contentType: 'application/json', body: JSON.stringify(json) });
    });

    await page.goto('/admin/news');
    await expect(page.getByText('News')).toBeVisible();
    await expect(page).toHaveScreenshot('admin-news-list.png', { fullPage: false, maxDiffPixelRatio: 0.02 });
  });

  test('open create form', async ({ page }) => {
    await page.route('**/api/v1/admin/news*', async route => {
      const json = [];
      await route.fulfill({ contentType: 'application/json', body: JSON.stringify(json) });
    });
    await page.goto('/admin/news');
    await page.getByRole('button', { name: /create/i }).click();
    await expect(page).toHaveURL(/.*\/admin\/news\/create/);
  });
});


