// Navigation state management for collapsible groups (vanilla JS version)

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', function() {
  initializeNavigation();
});

function initializeNavigation() {
  const sidebar = document.getElementById('navigation-sidebar');
  if (!sidebar) return;

  // Load saved state from localStorage
  const savedState = loadNavigationState();
  
  // Apply saved state to groups
  const groupButtons = sidebar.querySelectorAll('[data-group]');
  groupButtons.forEach(button => {
    const group = button.dataset.group;
    const stateKey = button.dataset.stateKey || `build_group_${group}`;
    const defaultExpanded = button.dataset.defaultExpanded === 'true';
    
    // Determine if group should be expanded
    const isExpanded = savedState[stateKey] !== undefined 
      ? savedState[stateKey] 
      : defaultExpanded;
    
    setGroupState(button, isExpanded, false); // Don't save on init
  });

  // Add keyboard event listeners
  sidebar.addEventListener('keydown', handleKeyboardNavigation);
}

// Global function for onclick handler
window.toggleNavigationGroup = function(button) {
  const isExpanded = button.getAttribute('aria-expanded') === 'true';
  const newState = !isExpanded;
  
  setGroupState(button, newState, true);
  announceStateChange(button, newState);
};

function setGroupState(button, isExpanded, shouldSave) {
  const group = button.dataset.group;
  const sidebar = document.getElementById('navigation-sidebar');
  const groupContent = sidebar.querySelector(`[data-group-content="${group}"]`);
  
  // Update button state
  button.setAttribute('aria-expanded', isExpanded.toString());
  
  // Update chevron icon
  const chevronIcon = button.querySelector('.icon svg');
  if (chevronIcon) {
    const chevronParent = chevronIcon.parentElement;
    if (isExpanded) {
      chevronParent.innerHTML = getChevronDownSvg();
      chevronParent.dataset.testid = 'chevron-down';
    } else {
      chevronParent.innerHTML = getChevronRightSvg();
      chevronParent.dataset.testid = 'chevron-right';
    }
  }
  
  // Update content visibility with animation
  if (groupContent) {
    if (isExpanded) {
      // Expand animation
      groupContent.classList.remove('hidden');
      groupContent.style.height = '0px';
      groupContent.style.overflow = 'hidden';
      
      // Force browser to calculate height
      const targetHeight = groupContent.scrollHeight;
      
      // Trigger animation
      requestAnimationFrame(() => {
        groupContent.style.transition = 'height 200ms ease-in-out';
        groupContent.style.height = targetHeight + 'px';
      });
      
      // Clean up after animation
      setTimeout(() => {
        groupContent.style.height = '';
        groupContent.style.overflow = '';
        groupContent.style.transition = '';
      }, 200);
    } else {
      // Collapse animation
      groupContent.style.overflow = 'hidden';
      groupContent.style.height = groupContent.scrollHeight + 'px';
      
      // Force browser reflow
      groupContent.offsetHeight;
      
      // Trigger animation
      requestAnimationFrame(() => {
        groupContent.style.transition = 'height 200ms ease-in-out';
        groupContent.style.height = '0px';
      });
      
      // Clean up after animation
      setTimeout(() => {
        groupContent.classList.add('hidden');
        groupContent.style.height = '';
        groupContent.style.overflow = '';
        groupContent.style.transition = '';
      }, 200);
    }
  }
  
  // Save state if requested
  if (shouldSave) {
    saveNavigationState();
  }
}

function saveNavigationState() {
  const state = {};
  const sidebar = document.getElementById('navigation-sidebar');
  const groupButtons = sidebar.querySelectorAll('[data-group]');
  
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
}

function loadNavigationState() {
  try {
    const saved = localStorage.getItem('sertantai_docs_navigation_state');
    return saved ? JSON.parse(saved) : {};
  } catch (e) {
    console.warn('Failed to load navigation state:', e);
    return {};
  }
}

function announceStateChange(button, isExpanded) {
  const announcer = document.getElementById('navigation-announcements');
  if (!announcer) return;
  
  const groupName = button.querySelector('span').textContent.trim();
  const itemCountElement = button.querySelector('.text-gray-400');
  const itemCount = itemCountElement ? itemCountElement.textContent : '';
  
  const message = isExpanded 
    ? `Expanded ${groupName} group${itemCount ? ' showing ' + itemCount : ''}`
    : `Collapsed ${groupName} group`;
  
  announcer.textContent = message;
}

function handleKeyboardNavigation(e) {
  const button = e.target.closest('[data-group]');
  if (!button) return;

  switch(e.key) {
    case 'Enter':
    case ' ':
      e.preventDefault();
      toggleNavigationGroup(button);
      break;
    case 'ArrowDown':
      if (button.getAttribute('aria-expanded') === 'true') {
        e.preventDefault();
        focusFirstChild(button);
      }
      break;
    case 'ArrowUp':
      e.preventDefault();
      focusPreviousGroup(button);
      break;
  }
}

function focusFirstChild(button) {
  const group = button.dataset.group;
  const sidebar = document.getElementById('navigation-sidebar');
  const groupContent = sidebar.querySelector(`[data-group-content="${group}"]`);
  const firstLink = groupContent?.querySelector('a, button');
  
  if (firstLink) {
    firstLink.focus();
  }
}

function focusPreviousGroup(button) {
  const sidebar = document.getElementById('navigation-sidebar');
  const allGroups = Array.from(sidebar.querySelectorAll('[data-group]'));
  const currentIndex = allGroups.indexOf(button);
  
  if (currentIndex > 0) {
    allGroups[currentIndex - 1].focus();
  }
}

// SVG icon helpers (matching Heroicons)
function getChevronDownSvg() {
  return '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" /></svg>';
}

function getChevronRightSvg() {
  return '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" /></svg>';
}