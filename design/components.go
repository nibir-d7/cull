package design

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

type Component struct {
	ID          string   `json:"id"`
	Role        string   `json:"role"`
	Async       bool     `json:"async"`
	Destructive bool     `json:"destructive"`
	Interactive bool     `json:"interactive"`
	States      []string `json:"states"`
	Props       []string `json:"props"`
	Tokens      []string `json:"tokens"`
	Notes       string   `json:"notes"`
}

type Screen struct {
	ID           string   `json:"id"`
	States       []string `json:"states"`
	RequiredCopy string   `json:"requiredCopy"`
}

type Inventory struct {
	Components    []Component       `json:"components"`
	Screens       []Screen          `json:"screens"`
	Accessibility []string          `json:"a11yChecklist"`
	StateRules    map[string]string `json:"_stateRules"`
}

var InteractiveStates = []string{"rest", "pressed", "focus", "disabled"}

var AsyncStates = []string{"loading", "empty", "error"}

func LoadInventory() (*Inventory, error) {
	b, err := files.ReadFile("components.json")
	if err != nil {
		return nil, err
	}
	var inv Inventory
	if err := json.Unmarshal(b, &inv); err != nil {
		return nil, fmt.Errorf("design: parse components.json: %w", err)
	}

	var problems []string
	if len(inv.Components) == 0 {
		problems = append(problems, "no components declared")
	}
	if len(inv.Screens) == 0 {
		problems = append(problems, "no screens declared")
	}
	if len(inv.Accessibility) == 0 {
		problems = append(problems, "no accessibility checklist declared")
	}

	ids := map[string]bool{}
	for _, c := range inv.Components {
		if c.ID == "" {
			problems = append(problems, "a component has no id")
			continue
		}
		if ids[c.ID] {
			problems = append(problems, "duplicate component id: "+c.ID)
		}
		ids[c.ID] = true
		if c.Role == "" {
			problems = append(problems, c.ID+": no role, so nobody knows what it is for")
		}
		if len(c.States) == 0 {
			problems = append(problems, c.ID+": no states declared")
			continue
		}
		seen := map[string]bool{}
		for _, s := range c.States {
			if seen[s] {
				problems = append(problems, c.ID+": duplicate state "+s)
			}
			seen[s] = true
		}

		if c.Destructive && !seen["undo"] {
			problems = append(problems, c.ID+": destructive component with no undo state")
		}

		if c.Async {
			for _, want := range AsyncStates {
				if !seen[want] {
					problems = append(problems, fmt.Sprintf("%s: loads data but has no %q state", c.ID, want))
				}
			}
		}

		if c.Interactive {
			for _, want := range []string{"focus", "disabled"} {
				if !seen[want] {
					problems = append(problems, fmt.Sprintf("%s: interactive but has no %q state", c.ID, want))
				}
			}
		}
	}

	screenIDs := map[string]bool{}
	for _, s := range inv.Screens {
		if s.ID == "" {
			problems = append(problems, "a screen has no id")
			continue
		}
		if screenIDs[s.ID] {
			problems = append(problems, "duplicate screen id: "+s.ID)
		}
		screenIDs[s.ID] = true

		if !hasState(s.States, "error") {
			problems = append(problems, s.ID+": no error state")
		}
	}

	if len(problems) > 0 {
		sort.Strings(problems)
		return nil, fmt.Errorf("design: %d inventory problem(s):\n  - %s",
			len(problems), strings.Join(problems, "\n  - "))
	}
	return &inv, nil
}

func hasState(states []string, want string) bool {
	for _, s := range states {
		if s == want {
			return true
		}
	}
	return false
}

func (i *Inventory) Component(id string) (Component, bool) {
	for _, c := range i.Components {
		if c.ID == id {
			return c, true
		}
	}
	return Component{}, false
}

func (i *Inventory) Screen(id string) (Screen, bool) {
	for _, s := range i.Screens {
		if s.ID == id {
			return s, true
		}
	}
	return Screen{}, false
}

func (i *Inventory) ComponentIDs() []string {
	out := make([]string, 0, len(i.Components))
	for _, c := range i.Components {
		out = append(out, c.ID)
	}
	sort.Strings(out)
	return out
}

func (i *Inventory) ScreenIDs() []string {
	out := make([]string, 0, len(i.Screens))
	for _, s := range i.Screens {
		out = append(out, s.ID)
	}
	sort.Strings(out)
	return out
}
