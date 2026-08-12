# Production Dockerfile for Yabu Supermarket Node.js Backend
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application source code
COPY . .

# Expose port
EXPOSE 5000

# Environment variables
ENV NODE_ENV=production
ENV PORT=5000

# Start server
CMD ["node", "src/server.js"]
