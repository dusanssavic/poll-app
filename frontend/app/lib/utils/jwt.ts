import { jwtDecode } from "jwt-decode";

export interface JWTPayload {
  user_id: string;
  email: string;
  username: string;
  exp?: number;
  iat?: number;
  nbf?: number;
}

/**
 * Decodes a JWT token and returns the payload
 */
export function decodeToken(token: string): JWTPayload | null {
  try {
    return jwtDecode<JWTPayload>(token);
  } catch (error) {
    return null;
  }
}

/**
 * Checks if a JWT token is expired
 */
export function isTokenExpired(token: string): boolean {
  const payload = decodeToken(token);
  if (!payload || !payload.exp) {
    return true;
  }
  
  // exp is in seconds, Date.now() is in milliseconds
  const expirationTime = payload.exp * 1000;
  const currentTime = Date.now();
  
  // Add a small buffer (5 seconds) to account for clock skew
  return currentTime >= expirationTime - 5000;
}

/**
 * Checks if a JWT token is valid (not expired and has required fields)
 */
export function isTokenValid(token: string): boolean {
  if (!token) {
    return false;
  }
  
  const payload = decodeToken(token);
  if (!payload) {
    return false;
  }
  
  // Check if token has required fields
  if (!payload.user_id || !payload.email || !payload.username) {
    return false;
  }
  
  // Check if token is expired
  return !isTokenExpired(token);
}

