// Created by takenncs
document.addEventListener('alpine:init', () => { 
    Alpine.data('boosting', () => ({
        showMenu: false,
        isLoading: false,
        inQueue: false,
        availableContracts: [],
        boostingXp: 0,
        levels: [],
        currentContract: '',
        lastActionTime: 0,

        async fetchNui(endpoint, data = {}) {
            try {
                const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data),
                });
                return await response.json();
            } catch {
                return null;
            }
        },

        async requestData() {
            this.isLoading = true;
            const data = await this.fetchNui('requestData');
            if (data) {
                this.inQueue = data.inQueue || false;
                this.availableContracts = data.availableContracts || [];
                this.boostingXp = data.boostingXp || 0;
                this.currentContract = data.currentContract || '';
            }
            this.isLoading = false;
        },

        async acceptContract(id) {
            const now = Date.now();
            if (this.isLoading || (now - this.lastActionTime < 1000)) {
                return;
            }
            if (!this.availableContracts.some(contract => contract.id === id)) {
                await this.requestData();
                return;
            }
            this.isLoading = true;
            this.lastActionTime = now;

            const data = await this.fetchNui('acceptContract', { id });
            if (data) {
                this.currentContract = data;
                await this.requestData();
            } else {
                await this.requestData();
            }
            this.isLoading = false;
        },

        async cancelContract(id) {
            const now = Date.now();
            if (this.isLoading || (now - this.lastActionTime < 1000)) {
                return;
            }
            this.isLoading = true;
            this.lastActionTime = now;

            const success = await this.fetchNui('cancelContract', { id });
            if (success) {
                this.currentContract = '';
                await this.requestData();
            } else {
                await this.requestData();
            }
            this.isLoading = false;
        },

        async joinQueue() {
            if (this.isLoading) return;
            this.isLoading = true;

            const success = await this.fetchNui('joinQueue');
            if (success) {
                this.inQueue = true;
                await this.requestData();
            }
            this.isLoading = false;
        },

        async leaveQueue() {
            if (this.isLoading) return;
            this.isLoading = true;

            const success = await this.fetchNui('leaveQueue');
            if (success) {
                this.inQueue = false;
                await this.requestData();
            }
            this.isLoading = false;
        },

        async closeMenu() {
            await this.fetchNui('closeMenu');
            this.showMenu = false;
        },

        handleKeydown({ keyCode }) {
            if (keyCode === 27) this.closeMenu();
        },

        init() {
            window.addEventListener('message', ({ data: eventData }) => {
                switch (eventData.action) {
                    case 'openMenu':
                        this.levels = eventData.data.levels;
                        this.showMenu = true;
                        this.requestData();
                        break;
                    case 'clearCurrent':
                        this.currentContract = '';
                        this.requestData();
                        break;
                    case 'requestData':
                        this.requestData();
                        break;
                }
            });

            window.addEventListener('keydown', this.handleKeydown.bind(this));
            setInterval(() => {
                if (this.showMenu) {
                    this.requestData();
                }
            }, 30000);
        },
    }));
});