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
  // Phoenix/Heroicons use CSS classes, not SVG elements
  const iconElement = button.querySelector('span[class*="hero-chevron"]');
  if (iconElement) {
    if (isExpanded) {
      // Change to chevron-down
      iconElement.className = iconElement.className.replace('hero-chevron-right', 'hero-chevron-down');
      iconElement.dataset.testid = 'chevron-down';
    } else {
      // Change to chevron-right
      iconElement.className = iconElement.className.replace('hero-chevron-down', 'hero-chevron-right');
      iconElement.dataset.testid = 'chevron-right';
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

// ===== ADVANCED FILTERING AND SORTING STATE MANAGEMENT =====

const FILTER_STORAGE_KEY = 'sertantai_docs_filters';
const SORT_STORAGE_KEY = 'sertantai_docs_sort';
const SEARCH_PREFERENCES_KEY = 'sertantai_docs_search_prefs';
const STATE_VERSION = 2;
const MAX_AGE_SECONDS = 86400 * 30; // 30 days

/**
 * Save filter state to localStorage
 * @param {Object} filters - Filter state object
 * @returns {boolean} - Success status
 */
window.saveFilterState = function(filters) {
  try {
    const stateToSave = {
      ...filters,
      timestamp: Math.floor(Date.now() / 1000),
      version: STATE_VERSION
    };
    
    localStorage.setItem(FILTER_STORAGE_KEY, JSON.stringify(stateToSave));
    syncStateAcrossTabs('filters', stateToSave);
    return true;
  } catch (error) {
    console.warn('Failed to save filter state:', error);
    // Try saving essential state only if quota exceeded
    try {
      const essentialState = {
        status: filters.status || "",
        category: filters.category || "",
        priority: filters.priority || "",
        timestamp: Math.floor(Date.now() / 1000),
        version: STATE_VERSION
      };
      localStorage.setItem(FILTER_STORAGE_KEY, JSON.stringify(essentialState));
      return true;
    } catch (fallbackError) {
      console.error('Failed to save even essential filter state:', fallbackError);
      return false;
    }
  }
};

/**
 * Load filter state from localStorage
 * @returns {Object} - Filter state object
 */
window.loadFilterState = function() {
  try {
    const saved = localStorage.getItem(FILTER_STORAGE_KEY);
    if (!saved) return getDefaultFilters();
    
    const state = JSON.parse(saved);
    
    // Check if state is expired
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const age = currentTimestamp - (state.timestamp || 0);
    if (age > MAX_AGE_SECONDS) {
      console.log('Filter state expired, using defaults');
      cleanupExpiredState();
      return getDefaultFilters();
    }
    
    // Migrate old state if needed
    if (state.version < STATE_VERSION) {
      return migrateFilterState(state);
    }
    
    // Validate state structure
    return validateFilterState(state);
  } catch (error) {
    console.warn('Failed to load filter state:', error);
    return getDefaultFilters();
  }
};

/**
 * Get default filter state
 * @returns {Object} - Default filter state
 */
window.getDefaultFilters = function() {
  return {
    status: "",
    category: "",
    priority: "",
    author: "",
    tags: [],
    version: STATE_VERSION,
    timestamp: Math.floor(Date.now() / 1000)
  };
};

/**
 * Save sort state to localStorage
 * @param {Object} sortOptions - Sort state object
 * @returns {boolean} - Success status
 */
window.saveSortState = function(sortOptions) {
  try {
    const stateToSave = {
      ...sortOptions,
      timestamp: Math.floor(Date.now() / 1000),
      version: STATE_VERSION
    };
    
    localStorage.setItem(SORT_STORAGE_KEY, JSON.stringify(stateToSave));
    syncStateAcrossTabs('sort', stateToSave);
    return true;
  } catch (error) {
    console.warn('Failed to save sort state:', error);
    return false;
  }
};

/**
 * Load sort state from localStorage
 * @returns {Object} - Sort state object
 */
window.loadSortState = function() {
  try {
    const saved = localStorage.getItem(SORT_STORAGE_KEY);
    if (!saved) return getDefaultSort();
    
    const state = JSON.parse(saved);
    
    // Check if state is expired
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const age = currentTimestamp - (state.timestamp || 0);
    if (age > MAX_AGE_SECONDS) {
      return getDefaultSort();
    }
    
    return validateSortState(state);
  } catch (error) {
    console.warn('Failed to load sort state:', error);
    return getDefaultSort();
  }
};

/**
 * Get default sort state
 * @returns {Object} - Default sort state
 */
window.getDefaultSort = function() {
  return {
    sort_by: "priority",
    sort_order: "asc",
    version: STATE_VERSION,
    timestamp: Math.floor(Date.now() / 1000)
  };
};

/**
 * Save search preferences to localStorage
 * @param {Object} preferences - Search preferences object
 * @returns {boolean} - Success status
 */
window.saveSearchPreferences = function(preferences) {
  try {
    const stateToSave = {
      ...preferences,
      timestamp: Math.floor(Date.now() / 1000),
      version: STATE_VERSION
    };
    
    localStorage.setItem(SEARCH_PREFERENCES_KEY, JSON.stringify(stateToSave));
    return true;
  } catch (error) {
    console.warn('Failed to save search preferences:', error);
    return false;
  }
};

/**
 * Load search preferences from localStorage
 * @returns {Object} - Search preferences object
 */
window.loadSearchPreferences = function() {
  try {
    const saved = localStorage.getItem(SEARCH_PREFERENCES_KEY);
    if (!saved) return getDefaultSearchPreferences();
    
    const state = JSON.parse(saved);
    return validateSearchPreferences(state);
  } catch (error) {
    console.warn('Failed to load search preferences:', error);
    return getDefaultSearchPreferences();
  }
};

/**
 * Get default search preferences
 * @returns {Object} - Default search preferences
 */
function getDefaultSearchPreferences() {
  return {
    include_tags: true,
    include_author: false,
    include_category: true,
    last_scope: "",
    recent_queries: [],
    version: STATE_VERSION,
    timestamp: Math.floor(Date.now() / 1000)
  };
}

/**
 * Sync state across browser tabs using storage events
 * @param {string} stateType - Type of state ('filters', 'sort', 'navigation')
 * @param {Object} state - State object to sync
 */
window.syncStateAcrossTabs = function(stateType, state) {
  // Storage events are automatically fired when localStorage changes
  // This function is here for consistency and future custom sync logic
  const syncEvent = new CustomEvent('stateSync', {
    detail: { stateType, state, tabId: generateTabId() }
  });
  window.dispatchEvent(syncEvent);
};

/**
 * Clean up expired state from localStorage
 * @param {number} maxAgeSeconds - Maximum age for state to be considered valid
 * @returns {number} - Number of cleaned up items
 */
window.cleanupExpiredState = function(maxAgeSeconds = MAX_AGE_SECONDS) {
  const keys = [FILTER_STORAGE_KEY, SORT_STORAGE_KEY, SEARCH_PREFERENCES_KEY, NAVIGATION_STORAGE_KEY];
  let cleanedCount = 0;
  
  keys.forEach(key => {
    try {
      const saved = localStorage.getItem(key);
      if (saved) {
        const state = JSON.parse(saved);
        const currentTimestamp = Math.floor(Date.now() / 1000);
        const age = currentTimestamp - (state.timestamp || 0);
        
        if (age > maxAgeSeconds) {
          localStorage.removeItem(key);
          cleanedCount++;
        }
      }
    } catch (error) {
      console.warn(`Failed to cleanup state for key ${key}:`, error);
    }
  });
  
  return cleanedCount;
};

/**
 * Migrate old state format to new format
 * @param {Object} oldState - Old state object
 * @returns {Object} - Migrated state object
 */
window.migrateOldState = function(oldState) {
  return migrateFilterState(oldState);
};

/**
 * Migrate old filter state format
 * @param {Object} oldState - Old filter state
 * @returns {Object} - Migrated filter state
 */
function migrateFilterState(oldState) {
  if (oldState.version === 1 && oldState.filters) {
    // Migrate version 1 format
    const [category, priority] = (oldState.filters || "").split(",");
    return {
      status: "",
      category: category || "",
      priority: priority || "",
      author: "",
      tags: [],
      version: STATE_VERSION,
      timestamp: Math.floor(Date.now() / 1000)
    };
  }
  
  return getDefaultFilters();
}

/**
 * Validate filter state structure
 * @param {Object} state - Filter state to validate
 * @returns {Object} - Validated filter state
 */
function validateFilterState(state) {
  const validStatuses = ["", "live", "archived"];
  const validPriorities = ["", "high", "medium", "low"];
  
  return {
    status: validStatuses.includes(state.status) ? state.status : "",
    category: typeof state.category === 'string' ? state.category : "",
    priority: validPriorities.includes(state.priority) ? state.priority : "",
    author: typeof state.author === 'string' ? state.author : "",
    tags: Array.isArray(state.tags) ? state.tags : [],
    version: state.version || STATE_VERSION,
    timestamp: state.timestamp || Math.floor(Date.now() / 1000)
  };
}

/**
 * Validate sort state structure
 * @param {Object} state - Sort state to validate
 * @returns {Object} - Validated sort state
 */
function validateSortState(state) {
  const validSortFields = ["priority", "title", "last_modified", "category"];
  const validSortOrders = ["asc", "desc"];
  
  return {
    sort_by: validSortFields.includes(state.sort_by) ? state.sort_by : "priority",
    sort_order: validSortOrders.includes(state.sort_order) ? state.sort_order : "asc",
    version: state.version || STATE_VERSION,
    timestamp: state.timestamp || Math.floor(Date.now() / 1000)
  };
}

/**
 * Validate search preferences structure
 * @param {Object} state - Search preferences to validate
 * @returns {Object} - Validated search preferences
 */
function validateSearchPreferences(state) {
  return {
    include_tags: typeof state.include_tags === 'boolean' ? state.include_tags : true,
    include_author: typeof state.include_author === 'boolean' ? state.include_author : false,
    include_category: typeof state.include_category === 'boolean' ? state.include_category : true,
    last_scope: typeof state.last_scope === 'string' ? state.last_scope : "",
    recent_queries: Array.isArray(state.recent_queries) ? state.recent_queries : [],
    version: state.version || STATE_VERSION,
    timestamp: state.timestamp || Math.floor(Date.now() / 1000)
  };
}

/**
 * Generate a unique tab ID for cross-tab synchronization
 * @returns {string} - Unique tab ID
 */
function generateTabId() {
  return `tab_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Handle URL parameter sync for shareable filtered views
 * @param {Object} state - Current state (filters + sort)
 * @returns {string} - URL parameters string
 */
window.generateUrlParams = function(state) {
  const params = new URLSearchParams();
  
  if (state.status) params.set('filter_status', state.status);
  if (state.category) params.set('filter_category', state.category);
  if (state.priority) params.set('filter_priority', state.priority);
  if (state.author) params.set('filter_author', state.author);
  if (state.sort_by) params.set('sort_by', state.sort_by);
  if (state.sort_order) params.set('sort_order', state.sort_order);
  if (state.expanded_groups && state.expanded_groups.length > 0) {
    params.set('groups', state.expanded_groups.join(','));
  }
  
  return params.toString();
};

/**
 * Parse URL parameters into state object
 * @param {string} urlParams - URL parameters string
 * @returns {Object} - Parsed state object
 */
window.parseUrlParams = function(urlParams) {
  const params = new URLSearchParams(urlParams);
  
  return {
    status: params.get('filter_status') || "",
    category: params.get('filter_category') || "",
    priority: params.get('filter_priority') || "",
    author: params.get('filter_author') || "",
    sort_by: params.get('sort_by') || "priority",
    sort_order: params.get('sort_order') || "asc",
    expanded_groups: params.get('groups') ? params.get('groups').split(',') : []
  };
};

// Listen for storage events from other tabs
window.addEventListener('storage', function(e) {
  if ([FILTER_STORAGE_KEY, SORT_STORAGE_KEY, SEARCH_PREFERENCES_KEY, NAVIGATION_STORAGE_KEY].includes(e.key)) {
    // State changed in another tab, reload if needed
    console.log(`State synchronized from another tab: ${e.key}`);
    
    // Optionally refresh the UI based on the changed state
    if (typeof window.handleStateSync === 'function') {
      window.handleStateSync(e.key, e.newValue);
    }
  }
});

// Cleanup expired state on page load
document.addEventListener('DOMContentLoaded', function() {
  // Clean up expired state in background
  setTimeout(() => {
    const cleanedCount = cleanupExpiredState();
    if (cleanedCount > 0) {
      console.log(`Cleaned up ${cleanedCount} expired state entries`);
    }
  }, 1000);
});