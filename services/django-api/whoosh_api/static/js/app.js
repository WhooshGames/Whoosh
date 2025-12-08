// Main Application Logic

const app = {
    async init() {
        // Check if user is already authenticated
        if (window.api.auth.isAuthenticated()) {
            try {
                await this.loadProfile();
                window.auth.showScreen('dashboard-screen');
            } catch (error) {
                // Token invalid, show landing page
                window.api.auth.logout();
                window.auth.showScreen('landing-screen');
            }
        } else {
            window.auth.showScreen('landing-screen');
        }
    },

    async loadProfile() {
        try {
            const profile = await window.api.user.getProfile();
            this.displayProfile(profile);
        } catch (error) {
            console.error('Failed to load profile:', error);
            throw error;
        }
    },

    displayProfile(profile) {
        // Update display name in header
        const displayNameElement = document.getElementById('user-display-name');
        if (displayNameElement) {
            displayNameElement.textContent = profile.display_name || profile.username;
        }

        // Update profile fields
        document.getElementById('profile-username').textContent = profile.username || '-';
        document.getElementById('profile-email').textContent = profile.email || 'Not set';
        document.getElementById('profile-display-name').textContent = profile.display_name || '-';
        document.getElementById('profile-elo').textContent = profile.elo || 1000;
        document.getElementById('profile-xp').textContent = profile.xp || 0;
        document.getElementById('profile-total-games').textContent = profile.total_games || 0;
        document.getElementById('profile-wins').textContent = profile.wins || 0;

        // Calculate win rate
        const winRate = profile.total_games > 0 
            ? ((profile.wins / profile.total_games) * 100).toFixed(1) + '%'
            : '0%';
        document.getElementById('profile-win-rate').textContent = winRate;

        // Show/hide guest badge
        const guestBadge = document.getElementById('guest-badge');
        const convertSection = document.getElementById('convert-guest-section');
        
        if (profile.is_guest) {
            if (guestBadge) guestBadge.style.display = 'block';
            if (convertSection) convertSection.style.display = 'block';
        } else {
            if (guestBadge) guestBadge.style.display = 'none';
            if (convertSection) convertSection.style.display = 'none';
        }
    },
};

// Initialize app when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => app.init());
} else {
    app.init();
}

// Export for use in other scripts
window.app = app;

