const get = (path) => ['GET', path];
const match = (name, routes, paths, method = 'GET') => ({ name, routes, paths, method });

export const registrationCases = [
  { name: 'create router', routes: [] },
  ...['static', 'dynamic', 'wildcard', 'regex'].map((kind, i) => ({
    name: `register ${kind}`,
    routes: [get(['/api/users', '/api/users/:id', '/api/*', '/api/users/:id{[0-9]+}'][i])],
  })),
  {
    name: 'register REST API',
    routes: ['users', 'posts'].flatMap((resource) => [
      ['GET', `/api/${resource}`], ['POST', `/api/${resource}`],
      ...['GET', 'PUT', 'DELETE'].map((method) => [method, `/api/${resource}/:id`]),
    ]),
  },
];

export const matchCases = [
  match('static short', ['/', '/api', '/api/users'].map(get), ['/api', '/api/users']),
  match('static long', [get('/api/v1/users/profile/settings')], ['/api/v1/users/profile/settings']),
  match('dynamic', [get('/api/users/:id')], ['/api/users/123', '/api/users/456']),
  match('nested dynamic', [get('/api/users/:user_id/posts/:post_id')], ['/api/users/123/posts/456', '/api/users/456/posts/789']),
  match('wildcard', [get('/api/*')], ['/api/users/123/posts', '/api/posts/456']),
  match('regex digits', [get('/api/users/:id{[0-9]+}')], ['/api/users/123', '/api/users/456']),
  match('regex UUID', [get('/api/items/:uuid{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}')], ['/api/items/550e8400-e29b-41d4-a716-446655440000']),
  match('middleware multi-match', [['ALL', '*'], get('/api/*'), get('/api/users'), get('/api/users/:id')], ['/api/users/123', '/api/users/456']),
  match('not found', ['/api/users', '/api/posts'].map(get), ['/not/found', '/missing']),
  match('100 static routes', Array.from({ length: 100 }, (_, i) => get(`/api/resource${i}`)), ['/api/resource50', '/api/resource99']),
  match('100 dynamic routes', Array.from({ length: 100 }, (_, i) => get(`/api/resource${i}/:id`)), ['/api/resource50/123', '/api/resource99/456']),
  match('mixed routes', ['/users/profile', '/users/:id', '/users/:id/settings', '/users/*'].map(get), ['/users/profile']),
  match('optional absent', [get('/api/items/:id?')], ['/api/items']),
  match('optional present', [get('/api/items/:id?')], ['/api/items/123', '/api/items/456']),
  match('deep overlap', ['/a/b/c/d/e', '/a/b/c/d/:e', '/a/b/c/:d/:e', '/a/b/:c/:d/:e', '/a/:b/:c/:d/:e'].map(get), ['/a/b/c/d/e']),
  match('ALL method', [['ALL', '/api/users']], ['/api/users'], 'POST'),
];
