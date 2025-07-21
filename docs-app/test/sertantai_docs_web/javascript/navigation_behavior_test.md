# JavaScript Navigation Behavior Tests

These test specifications define the expected JavaScript behavior for the collapsible navigation groups. These should be implemented as actual JavaScript tests (Jest, Cypress, or similar) when we create the frontend components.

## Core Interaction Tests

### Test: Group Toggle Functionality
```javascript
describe('Group Toggle Functionality', () => {
  test('should expand collapsed group on click', () => {
    // Given: A collapsed group
    const groupButton = document.querySelector('[data-group="done"] .group-toggle');
    const groupContent = document.querySelector('[data-group="done"] .group-children');
    
    expect(groupButton.getAttribute('aria-expanded')).toBe('false');
    expect(groupContent.style.display).toBe('none');
    
    // When: User clicks the group toggle
    groupButton.click();
    
    // Then: Group should expand
    expect(groupButton.getAttribute('aria-expanded')).toBe('true');
    expect(groupContent.style.display).not.toBe('none');
    expect(groupButton.querySelector('.chevron')).toHaveClass('chevron-down');
  });

  test('should collapse expanded group on click', () => {
    // Given: An expanded group
    const groupButton = document.querySelector('[data-group="todo"] .group-toggle');
    const groupContent = document.querySelector('[data-group="todo"] .group-children');
    
    // Setup expanded state
    groupButton.setAttribute('aria-expanded', 'true');
    groupContent.style.display = 'block';
    
    // When: User clicks the group toggle
    groupButton.click();
    
    // Then: Group should collapse
    expect(groupButton.getAttribute('aria-expanded')).toBe('false');
    expect(groupContent.style.display).toBe('none');
    expect(groupButton.querySelector('.chevron')).toHaveClass('chevron-right');
  });

  test('should handle multiple groups independently', () => {
    // Given: Multiple groups
    const doneButton = document.querySelector('[data-group="done"] .group-toggle');
    const todoButton = document.querySelector('[data-group="todo"] .group-toggle');
    
    // When: Expand done group
    doneButton.click();
    
    // Then: Only done group should be affected
    expect(doneButton.getAttribute('aria-expanded')).toBe('true');
    expect(todoButton.getAttribute('aria-expanded')).toBe('false'); // Unchanged
  });
});
```

### Test: State Persistence
```javascript
describe('State Persistence', () => {
  test('should save state to localStorage on toggle', () => {
    // Given: A group toggle
    const groupButton = document.querySelector('[data-group="done"] .group-toggle');
    
    // When: User toggles group
    groupButton.click();
    
    // Then: State should be saved to localStorage
    const savedState = JSON.parse(localStorage.getItem('sertantai_docs_navigation_state'));
    expect(savedState['build_group_done']).toBe(true);
  });

  test('should restore state from localStorage on page load', () => {
    // Given: Saved state in localStorage
    const savedState = {
      'build_group_done': true,
      'build_group_strategy': false,
      'build_group_todo': true
    };
    localStorage.setItem('sertantai_docs_navigation_state', JSON.stringify(savedState));
    
    // When: Page loads (simulate page load)
    initializeNavigation();
    
    // Then: Groups should be in saved state
    expect(document.querySelector('[data-group="done"]').getAttribute('aria-expanded')).toBe('true');
    expect(document.querySelector('[data-group="strategy"]').getAttribute('aria-expanded')).toBe('false');
    expect(document.querySelector('[data-group="todo"]').getAttribute('aria-expanded')).toBe('true');
  });

  test('should fall back to defaults when localStorage is unavailable', () => {
    // Given: localStorage is disabled/full
    Object.defineProperty(window, 'localStorage', {
      value: {
        getItem: () => { throw new Error('localStorage not available'); },
        setItem: () => { throw new Error('localStorage not available'); }
      }
    });
    
    // When: Page loads
    initializeNavigation();
    
    // Then: Should use default expansion state
    expect(document.querySelector('[data-group="todo"]').getAttribute('aria-expanded')).toBe('true');
    expect(document.querySelector('[data-group="done"]').getAttribute('aria-expanded')).toBe('false');
  });
});
```

### Test: Keyboard Navigation
```javascript
describe('Keyboard Navigation', () => {
  test('should toggle group on Enter key', () => {
    // Given: Focused group toggle
    const groupButton = document.querySelector('[data-group="done"] .group-toggle');
    groupButton.focus();
    
    // When: User presses Enter
    const enterEvent = new KeyboardEvent('keydown', { key: 'Enter' });
    groupButton.dispatchEvent(enterEvent);
    
    // Then: Group should toggle
    expect(groupButton.getAttribute('aria-expanded')).toBe('true');
  });

  test('should toggle group on Space key', () => {
    // Given: Focused group toggle
    const groupButton = document.querySelector('[data-group="strategy"] .group-toggle');
    groupButton.focus();
    
    // When: User presses Space
    const spaceEvent = new KeyboardEvent('keydown', { key: ' ' });
    groupButton.dispatchEvent(spaceEvent);
    
    // Then: Group should toggle
    expect(groupButton.getAttribute('aria-expanded')).toBe('true');
  });

  test('should navigate to first child on ArrowDown', () => {
    // Given: Expanded group with children
    const groupButton = document.querySelector('[data-group="done"] .group-toggle');
    groupButton.click(); // Expand
    
    const firstChild = document.querySelector('[data-group="done"] .group-children a:first-child');
    
    // When: User presses ArrowDown on group
    const arrowEvent = new KeyboardEvent('keydown', { key: 'ArrowDown' });
    groupButton.dispatchEvent(arrowEvent);
    
    // Then: First child should be focused
    expect(document.activeElement).toBe(firstChild);
  });

  test('should handle Tab navigation correctly', () => {
    // Given: Navigation structure
    const groupToggles = document.querySelectorAll('.group-toggle');
    
    // When/Then: Tab should move between group toggles in order
    for (let i = 0; i < groupToggles.length - 1; i++) {
      groupToggles[i].focus();
      const tabEvent = new KeyboardEvent('keydown', { key: 'Tab' });
      groupToggles[i].dispatchEvent(tabEvent);
      
      // Next toggle should be focusable
      expect(groupToggles[i + 1].tabIndex).toBe(0);
    }
  });
});
```

### Test: Accessibility Features
```javascript
describe('Accessibility Features', () => {
  test('should announce state changes to screen readers', () => {
    // Mock aria-live region
    const announcements = document.querySelector('#navigation-announcements');
    
    // Given: A collapsed group
    const groupButton = document.querySelector('[data-group="done"] .group-toggle');
    
    // When: Group is expanded
    groupButton.click();
    
    // Then: Announcement should be made
    expect(announcements.textContent).toContain('Expanded Done group showing');
    expect(announcements.textContent).toContain('items');
  });

  test('should maintain proper ARIA attributes', () => {
    // Given: Navigation groups
    const groupButtons = document.querySelectorAll('.group-toggle');
    
    for (const button of groupButtons) {
      // Should have required ARIA attributes
      expect(button).toHaveAttribute('aria-expanded');
      expect(button).toHaveAttribute('aria-label');
      expect(button).toHaveAttribute('role', 'button');
      
      // ARIA-expanded should match visual state
      const isExpanded = button.getAttribute('aria-expanded') === 'true';
      const hasDownChevron = button.querySelector('.chevron').classList.contains('chevron-down');
      expect(isExpanded).toBe(hasDownChevron);
    }
  });

  test('should provide appropriate focus indicators', () => {
    // Given: A group toggle
    const groupButton = document.querySelector('[data-group="done"] .group-toggle');
    
    // When: Button receives focus
    groupButton.focus();
    
    // Then: Should have visible focus indicator
    const computedStyle = window.getComputedStyle(groupButton);
    expect(computedStyle.outline).not.toBe('none');
    // OR: expect(groupButton).toHaveClass('focus-visible');
  });
});
```

### Test: Animation and Transitions
```javascript
describe('Animation and Transitions', () => {
  test('should animate group expansion smoothly', (done) => {
    // Given: A collapsed group
    const groupContent = document.querySelector('[data-group="done"] .group-children');
    const groupButton = document.querySelector('[data-group="done"] .group-toggle');
    
    expect(groupContent.style.height).toBe('0px');
    
    // When: Group is expanded
    groupButton.click();
    
    // Then: Should animate height
    setTimeout(() => {
      expect(groupContent.style.height).not.toBe('0px');
      expect(groupContent.classList).toContain('expanding');
      done();
    }, 100);
  });

  test('should animate group collapse smoothly', (done) => {
    // Given: An expanded group
    const groupContent = document.querySelector('[data-group="todo"] .group-children');
    const groupButton = document.querySelector('[data-group="todo"] .group-toggle');
    
    // Setup expanded state
    groupContent.style.height = 'auto';
    
    // When: Group is collapsed
    groupButton.click();
    
    // Then: Should animate to closed
    setTimeout(() => {
      expect(groupContent.style.height).toBe('0px');
      expect(groupContent.classList).toContain('collapsing');
      done();
    }, 100);
  });

  test('should handle rapid clicks gracefully', () => {
    // Given: A group toggle
    const groupButton = document.querySelector('[data-group="strategy"] .group-toggle');
    
    // When: User clicks rapidly multiple times
    for (let i = 0; i < 5; i++) {
      groupButton.click();
    }
    
    // Then: Should be in a stable state (not stuck in transition)
    const groupContent = document.querySelector('[data-group="strategy"] .group-children');
    expect(groupContent.classList).not.toContain('transitioning');
  });
});
```

### Test: Error Handling
```javascript
describe('Error Handling', () => {
  test('should handle missing group elements gracefully', () => {
    // Given: Malformed DOM (missing group content)
    const groupButton = document.querySelector('[data-group="done"] .group-toggle');
    const groupContent = document.querySelector('[data-group="done"] .group-children');
    groupContent.remove(); // Simulate missing content
    
    // When: User clicks toggle
    expect(() => {
      groupButton.click();
    }).not.toThrow();
    
    // Then: Should handle gracefully (no crash)
    expect(groupButton.getAttribute('aria-expanded')).toBe('false');
  });

  test('should recover from localStorage errors', () => {
    // Given: Corrupted localStorage data
    localStorage.setItem('sertantai_docs_navigation_state', 'invalid json{');
    
    // When: Page loads
    expect(() => {
      initializeNavigation();
    }).not.toThrow();
    
    // Then: Should fall back to defaults
    expect(document.querySelector('[data-group="todo"]').getAttribute('aria-expanded')).toBe('true');
  });

  test('should handle groups with no children', () => {
    // Given: Group with empty children array
    const emptyGroupButton = document.querySelector('[data-group="empty"] .group-toggle');
    
    // When: User clicks toggle
    emptyGroupButton.click();
    
    // Then: Should handle gracefully
    expect(emptyGroupButton.getAttribute('aria-expanded')).toBe('true');
    // No error should occur
  });
});
```

## Implementation Checklist

When implementing the JavaScript, ensure these behaviors are working:

- [ ] **Group Toggle**: Click to expand/collapse groups
- [ ] **State Persistence**: Save/restore state in localStorage  
- [ ] **Keyboard Navigation**: Enter, Space, Arrow keys
- [ ] **Accessibility**: ARIA attributes, screen reader announcements
- [ ] **Animation**: Smooth expand/collapse transitions
- [ ] **Error Handling**: Graceful degradation for edge cases
- [ ] **Performance**: Efficient DOM updates, debounced storage
- [ ] **Focus Management**: Logical tab order, focus indicators

## Testing Commands

```bash
# Run JavaScript tests (when implemented)
npm test -- navigation

# Run accessibility tests
npm run test:a11y

# Run integration tests
npm run test:integration

# Check bundle size impact
npm run analyze
```

## Notes

These tests define the expected behavior for the JavaScript implementation of Phase 2. They should be converted to actual test files using your preferred JavaScript testing framework (Jest, Vitest, Cypress, etc.) when implementing the frontend components.

The tests cover all major interaction patterns, accessibility requirements, and edge cases to ensure a robust implementation that matches the original plan specifications.