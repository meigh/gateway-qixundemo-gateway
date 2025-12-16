FROM nginx:1.29-alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY conf.d/.htpasswd /etc/nginx/.htpasswd

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]