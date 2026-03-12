# Stage 1: Build the Flutter app for web
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

USER root
WORKDIR /app

# Copy the entire frontend directory
COPY . .

# Install dependencies
RUN flutter pub get

# Build the web application
RUN flutter build web --release

# Stage 2: Serve the app using Nginx
FROM nginx:alpine

# Copy the built web files from the build stage to Nginx's web root
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port 80 inside the container
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
