# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
# LocalLLM Dashboard Portal — nginx reverse proxy + static dashboard
# Build context must be the project root directory.

FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy nginx config and static dashboard files
COPY docker/dashboard/nginx.conf /etc/nginx/conf.d/default.conf
COPY dashboard/ /usr/share/nginx/html/

HEALTHCHECK --interval=30s --timeout=5s \
  CMD wget -q --spider http://localhost:3100/health || exit 1

EXPOSE 3100
