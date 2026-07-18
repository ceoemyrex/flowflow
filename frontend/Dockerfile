FROM nginx:1.27-alpine

ARG GIT_SHA=unknown
ARG BUILD_VERSION=dev
ARG BUILT_AT=unknown

COPY index.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Version metadata only, generated at build time — no secrets in a static frontend image.
RUN echo "window.__FRONTEND_VERSION__ = '${BUILD_VERSION} (${GIT_SHA})';" \
    > /usr/share/nginx/html/version.js

EXPOSE 80

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:80/ > /dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
