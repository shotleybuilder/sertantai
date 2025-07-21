// Navigation state management for collapsible groups
export default {
  mounted() {
    this.initializeNavigation();
    this.bindEventListeners();
  },

  initializeNavigation() {
    // Load saved state from localStorage
    const savedState = this.loadState();
    
    // Apply saved state to groups
    const groupButtons = this.el.querySelectorAll('[data-group]');
    groupButtons.forEach(button => {
      const group = button.dataset.group;
      const stateKey = button.dataset.stateKey || `build_group_${group}`;
      const defaultExpanded = button.dataset.defaultExpanded === 'true';
      
      // Determine if group should be expanded
      const isExpanded = savedState[stateKey] !== undefined 
        ? savedState[stateKey] 
        : defaultExpanded;
      
      this.setGroupState(button, isExpanded);
    });
  },

  bindEventListeners() {
    // Click handlers for group toggles
    this.el.addEventListener('click', (e) => {
      const button = e.target.closest('[data-group]');
      if (button) {
        e.preventDefault();
        this.toggleGroup(button);
      }
    });

    // Keyboard navigation
    this.el.addEventListener('keydown', (e) => {
      const button = e.target.closest('[data-group]');
      if (!button) return;

      switch(e.key) {
        case 'Enter':
        case ' ':
          e.preventDefault();
          this.toggleGroup(button);
          break;
        case 'ArrowDown':
          if (button.getAttribute('aria-expanded') === 'true') {
            e.preventDefault();
            this.focusFirstChild(button);
          }
          break;
        case 'ArrowUp':
          e.preventDefault();
          this.focusPreviousGroup(button);
          break;
      }
    });
  },

  toggleGroup(button) {
    const isExpanded = button.getAttribute('aria-expanded') === 'true';
    const newState = !isExpanded;
    
    this.setGroupState(button, newState);
    this.saveState();
    this.announceStateChange(button, newState);
  },

  setGroupState(button, isExpanded) {
    const group = button.dataset.group;
    const groupContent = this.el.querySelector(`[data-group-content="${group}"]`);
    
    // Update button state
    button.setAttribute('aria-expanded', isExpanded.toString());
    
    // Update chevron icon
    const chevron = button.querySelector('[data-testid*="chevron"]');
    if (chevron) {
      if (isExpanded) {
        chevron.classList.remove('hero-chevron-right');
        chevron.classList.add('hero-chevron-down');
        chevron.dataset.testid = 'chevron-down';
      } else {
        chevron.classList.remove('hero-chevron-down');
        chevron.classList.add('hero-chevron-right');
        chevron.dataset.testid = 'chevron-right';
      }
    }
    
    // Update content visibility with animation
    if (groupContent) {
      if (isExpanded) {
        groupContent.classList.remove('hidden');
        // Animate expansion
        const height = groupContent.scrollHeight;
        groupContent.style.height = '0px';
        groupContent.offsetHeight; // Force reflow
        groupContent.style.transition = 'height 200ms ease-in-out';
        groupContent.style.height = height + 'px';
        
        setTimeout(() => {
          groupContent.style.height = 'auto';
          groupContent.style.transition = '';
        }, 200);
      } else {
        // Animate collapse
        const height = groupContent.scrollHeight;
        groupContent.style.height = height + 'px';
        groupContent.offsetHeight; // Force reflow
        groupContent.style.transition = 'height 200ms ease-in-out';
        groupContent.style.height = '0px';
        
        setTimeout(() => {
          groupContent.classList.add('hidden');
          groupContent.style.height = '';
          groupContent.style.transition = '';
        }, 200);
      }
    }
  },

  saveState() {
    const state = {};
    const groupButtons = this.el.querySelectorAll('[data-group]');
    
    groupButtons.forEach(button => {
      const group = button.dataset.group;
      const stateKey = button.dataset.stateKey || `build_group_${group}`;
      const isExpanded = button.getAttribute('aria-expanded') === 'true';
      state[stateKey] = isExpanded;
    });
    
    try {
      localStorage.setItem('sertantai_docs_navigation_state', JSON.stringify(state));
    } catch (e) {
      console.warn('Failed to save navigation state:', e);
    }
  },

  loadState() {
    try {
      const saved = localStorage.getItem('sertantai_docs_navigation_state');
      return saved ? JSON.parse(saved) : {};
    } catch (e) {
      console.warn('Failed to load navigation state:', e);
      return {};
    }
  },

  announceStateChange(button, isExpanded) {
    const announcer = document.getElementById('navigation-announcements');
    if (!announcer) return;
    
    const groupName = button.querySelector('span').textContent.trim();
    const itemCount = button.querySelector('.text-gray-400')?.textContent || '';
    
    const message = isExpanded 
      ? `Expanded ${groupName} group showing ${itemCount}`
      : `Collapsed ${groupName} group`;
    
    announcer.textContent = message;
  },

  focusFirstChild(button) {
    const group = button.dataset.group;
    const groupContent = this.el.querySelector(`[data-group-content="${group}"]`);
    const firstLink = groupContent?.querySelector('a, button');
    
    if (firstLink) {
      firstLink.focus();
    }
  },

  focusPreviousGroup(button) {
    const allGroups = Array.from(this.el.querySelectorAll('[data-group]'));
    const currentIndex = allGroups.indexOf(button);
    
    if (currentIndex > 0) {
      allGroups[currentIndex - 1].focus();
    }
  }
};