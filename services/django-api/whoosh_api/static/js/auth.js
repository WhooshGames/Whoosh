// Authentication UI Handlers

function showScreen(screenId) {
    // Hide all screens
    document.querySelectorAll('.screen').forEach(screen => {
        screen.classList.remove('active');
    });
    
    // Show target screen
    const targetScreen = document.getElementById(screenId);
    if (targetScreen) {
        targetScreen.classList.add('active');
    }
}

function showError(elementId, message) {
    const errorElement = document.getElementById(elementId);
    if (errorElement) {
        errorElement.textContent = message;
        errorElement.style.display = 'block';
        setTimeout(() => {
            errorElement.style.display = 'none';
        }, 5000);
    }
}

function clearError(elementId) {
    const errorElement = document.getElementById(elementId);
    if (errorElement) {
        errorElement.textContent = '';
        errorElement.style.display = 'none';
    }
}

// Initialize event listeners
document.addEventListener('DOMContentLoaded', () => {
    // Landing page buttons
    const loginBtn = document.getElementById('login-btn');
    const registerBtn = document.getElementById('register-btn');
    const guestBtn = document.getElementById('guest-btn');

    if (loginBtn) {
        loginBtn.addEventListener('click', () => showScreen('login-screen'));
    }
    if (registerBtn) {
        registerBtn.addEventListener('click', () => showScreen('register-screen'));
    }
    if (guestBtn) {
        guestBtn.addEventListener('click', () => showScreen('guest-screen'));
    }

    // Back buttons
    const loginBack = document.getElementById('login-back');
    const registerBack = document.getElementById('register-back');
    const guestBack = document.getElementById('guest-back');

    if (loginBack) {
        loginBack.addEventListener('click', () => showScreen('landing-screen'));
    }
    if (registerBack) {
        registerBack.addEventListener('click', () => showScreen('landing-screen'));
    }
    if (guestBack) {
        guestBack.addEventListener('click', () => showScreen('landing-screen'));
    }

    // Login form
    const loginForm = document.getElementById('login-form');
    if (loginForm) {
        loginForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            clearError('login-error');

            const username = document.getElementById('login-username').value;
            const password = document.getElementById('login-password').value;

            try {
                const data = await window.api.auth.login(username, password);
                // Load profile and show dashboard
                await window.app.loadProfile();
                showScreen('dashboard-screen');
            } catch (error) {
                showError('login-error', error.message);
            }
        });
    }

    // Register form
    const registerForm = document.getElementById('register-form');
    if (registerForm) {
        registerForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            clearError('register-error');

            const username = document.getElementById('register-username').value;
            const email = document.getElementById('register-email').value;
            const password = document.getElementById('register-password').value;

            try {
                const data = await window.api.auth.register(username, email, password);
                // Load profile and show dashboard
                await window.app.loadProfile();
                showScreen('dashboard-screen');
            } catch (error) {
                showError('register-error', error.message);
            }
        });
    }

    // Guest form
    const guestForm = document.getElementById('guest-form');
    if (guestForm) {
        guestForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            clearError('guest-error');

            const displayName = document.getElementById('guest-display-name').value || null;

            try {
                const data = await window.api.auth.createGuest(displayName);
                // Load profile and show dashboard
                await window.app.loadProfile();
                showScreen('dashboard-screen');
            } catch (error) {
                showError('guest-error', error.message);
            }
        });
    }

    // Logout button
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', () => {
            window.api.auth.logout();
            showScreen('landing-screen');
        });
    }

    // Convert guest form
    const convertGuestForm = document.getElementById('convert-guest-form');
    if (convertGuestForm) {
        convertGuestForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            clearError('convert-error');

            const username = document.getElementById('convert-username').value;
            const email = document.getElementById('convert-email').value;
            const password = document.getElementById('convert-password').value;

            try {
                const data = await window.api.auth.convertGuest(username, email, password);
                // Reload profile to show updated data
                await window.app.loadProfile();
                // Show success message
                const errorElement = document.getElementById('convert-error');
                if (errorElement) {
                    errorElement.style.background = '#d1fae5';
                    errorElement.style.color = '#065f46';
                    errorElement.style.border = '1px solid #a7f3d0';
                    errorElement.textContent = 'Account converted successfully!';
                    errorElement.style.display = 'block';
                    setTimeout(() => {
                        errorElement.style.display = 'none';
                        errorElement.style.background = '#fee2e2';
                        errorElement.style.color = '#dc2626';
                        errorElement.style.border = '1px solid #fecaca';
                    }, 5000);
                }
            } catch (error) {
                showError('convert-error', error.message);
            }
        });
    }
});

// Export showScreen for use in app.js
window.auth = { showScreen, showError, clearError };

