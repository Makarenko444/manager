# syntax=docker/dockerfile:1
FROM nginx:1.25-alpine

COPY index.html /usr/share/nginx/html/index.html
COPY styles.css /usr/share/nginx/html/styles.css

EXPOSE 80
