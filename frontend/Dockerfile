FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

ARG REACT_APP_AUTH_API_URL=/proxy/auth/api
ARG REACT_APP_STREAMING_API_URL=/proxy/streaming/api/streaming
ARG REACT_APP_STREAMING_PUBLIC_URL=/proxy/streaming
ARG REACT_APP_ADMIN_API_URL=/proxy/admin/api/admin
ARG REACT_APP_CHAT_API_URL=/proxy/chat/api/chat
ARG REACT_APP_CHAT_SOCKET_URL=""

ENV REACT_APP_AUTH_API_URL=${REACT_APP_AUTH_API_URL}
ENV REACT_APP_STREAMING_API_URL=${REACT_APP_STREAMING_API_URL}
ENV REACT_APP_STREAMING_PUBLIC_URL=${REACT_APP_STREAMING_PUBLIC_URL}
ENV REACT_APP_ADMIN_API_URL=${REACT_APP_ADMIN_API_URL}
ENV REACT_APP_CHAT_API_URL=${REACT_APP_CHAT_API_URL}
ENV REACT_APP_CHAT_SOCKET_URL=${REACT_APP_CHAT_SOCKET_URL}

RUN npm run build

FROM nginx:1.27-alpine AS production
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1/health || exit 1
CMD ["nginx", "-g", "daemon off;"]
