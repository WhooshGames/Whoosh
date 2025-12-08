// API Client for Whoosh Backend

const API_BASE_URL = '/api';

// Get stored tokens
function getTokens() {
    const accessToken = localStorage.getItem('access_token');
    const refreshToken = localStorage.getItem('refresh_token');
    return { accessToken, refreshToken };
}

// Store tokens
function setTokens(accessToken, refreshToken) {
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
}

// Clear tokens
function clearTokens() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
}

// Make API request with authentication
async function apiRequest(endpoint, options = {}) {
    const { accessToken } = getTokens();
    const headers = {
        'Content-Type': 'application/json',
        ...options.headers,
    };

    if (accessToken) {
        headers['Authorization'] = `Bearer ${accessToken}`;
    }

    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        ...options,
        headers,
    });

    // Handle 401 Unauthorized - token might be expired
    if (response.status === 401 && accessToken) {
        // Try to refresh token
        const refreshed = await refreshAccessToken();
        if (refreshed) {
            // Retry request with new token
            const { accessToken: newToken } = getTokens();
            headers['Authorization'] = `Bearer ${newToken}`;
            return fetch(`${API_BASE_URL}${endpoint}`, {
                ...options,
                headers,
            });
        } else {
            // Refresh failed, clear tokens
            clearTokens();
            throw new Error('Session expired. Please login again.');
        }
    }

    return response;
}

// Refresh access token
async function refreshAccessToken() {
    const { refreshToken } = getTokens();
    if (!refreshToken) {
        return false;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/auth/token/refresh/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ refresh: refreshToken }),
        });

        if (!response.ok) {
            return false;
        }

        if (response.ok) {
            const data = await response.json();
            setTokens(data.access, refreshToken);
            return true;
        }
    } catch (error) {
        console.error('Token refresh failed:', error);
    }

    return false;
}

// Authentication API
const auth = {
    async login(username, password) {
        const response = await fetch(`${API_BASE_URL}/auth/login/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ username, password }),
        });

        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || data.detail || 'Login failed');
        }

        setTokens(data.access, data.refresh);
        return data;
    },

    async register(username, email, password) {
        const response = await fetch(`${API_BASE_URL}/auth/register/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ username, email, password }),
        });

        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || data.detail || 'Registration failed');
        }

        setTokens(data.access, data.refresh);
        return data;
    },

    async createGuest(displayName = null) {
        const response = await fetch(`${API_BASE_URL}/auth/guest/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ display_name: displayName }),
        });

        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || data.detail || 'Failed to create guest account');
        }

        setTokens(data.access, data.refresh);
        return data;
    },

    async convertGuest(username, email, password) {
        const response = await apiRequest('/auth/convert-guest/', {
            method: 'POST',
            body: JSON.stringify({ username, email, password }),
        });

        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || data.detail || 'Failed to convert guest account');
        }

        // Update tokens if new ones are provided
        if (data.access && data.refresh) {
            setTokens(data.access, data.refresh);
        }

        return data;
    },

    logout() {
        clearTokens();
    },

    isAuthenticated() {
        return !!getTokens().accessToken;
    },
};

// User API
const user = {
    async getProfile() {
        const response = await apiRequest('/users/me/');
        
        if (!response.ok) {
            throw new Error('Failed to fetch profile');
        }

        return await response.json();
    },

    async updateProfile(data) {
        const response = await apiRequest('/users/me/', {
            method: 'PATCH',
            body: JSON.stringify(data),
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || errorData.detail || 'Failed to update profile');
        }

        return await response.json();
    },
};

// Export for use in other scripts
window.api = { auth, user, getTokens, clearTokens };

