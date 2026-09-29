package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"encoding/json"
	"sync"
	"unsafe"

	"github.com/cull-app/cull/bind"
)

var (
	mu     sync.Mutex
	stores []*bind.Store
)

func main() {}

func storeAt(h C.int) *bind.Store {
	mu.Lock()
	defer mu.Unlock()
	if h < 0 || int(h) >= len(stores) {
		return nil
	}
	return stores[h]
}

func out(v any) *C.char {
	b, err := json.Marshal(v)
	if err != nil {
		b = []byte(`{"error":"marshal failed"}`)
	}
	return C.CString(string(b))
}

//export CULLFree
func CULLFree(p *C.char) {
	if p != nil {
		C.free(unsafe.Pointer(p))
	}
}

//export CULLOpen
func CULLOpen(path *C.char) C.int {
	if path == nil {
		return -1
	}
	s, err := bind.NewStore(C.GoString(path))
	if err != nil {
		return -1
	}
	mu.Lock()
	stores = append(stores, s)
	mu.Unlock()
	return C.int(len(stores) - 1)
}

//export CULLClose
func CULLClose(h C.int) {
	s := storeAt(h)
	if s == nil {
		return
	}
	_ = s.Close()
	mu.Lock()
	if int(h) < len(stores) {
		stores[h] = nil
	}
	mu.Unlock()
}

//export CULLSave
func CULLSave(h C.int, url *C.char, week C.int) *C.char {
	s := storeAt(h)
	if s == nil || url == nil {
		return out(map[string]any{"error": "bad store"})
	}
	res, err := s.Save(C.GoString(url), int(week))
	if err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(res)
}

//export CULLList
func CULLList(h C.int, limit C.int) *C.char {
	s := storeAt(h)
	if s == nil {
		return out([]any{})
	}
	links, err := s.List(int(limit))
	if err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(links)
}

//export CULLSearch
func CULLSearch(h C.int, q *C.char, limit C.int) *C.char {
	s := storeAt(h)
	if s == nil || q == nil {
		return out([]any{})
	}
	links, err := s.Search(C.GoString(q), int(limit))
	if err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(links)
}

//export CULLCullable
func CULLCullable(h C.int, limit C.int) *C.char {
	s := storeAt(h)
	if s == nil {
		return out([]any{})
	}
	links, err := s.Cullable(int(limit))
	if err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(links)
}

//export CULLGraveyard
func CULLGraveyard(h C.int, limit C.int) *C.char {
	s := storeAt(h)
	if s == nil {
		return out([]any{})
	}
	links, err := s.Graveyard(int(limit))
	if err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(links)
}

//export CULLCull
func CULLCull(h C.int, id *C.char, nowMillis C.longlong) *C.char {
	s := storeAt(h)
	if s == nil || id == nil {
		return out(map[string]any{"error": "bad store"})
	}
	if err := s.Cull(C.GoString(id), int64(nowMillis)); err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(map[string]any{"ok": true})
}

//export CULLRestore
func CULLRestore(h C.int, id *C.char) *C.char {
	s := storeAt(h)
	if s == nil || id == nil {
		return out(map[string]any{"error": "bad store"})
	}
	if err := s.Restore(C.GoString(id)); err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(map[string]any{"ok": true})
}

//export CULLTouchOpen
func CULLTouchOpen(h C.int, id *C.char, nowMillis C.longlong) *C.char {
	s := storeAt(h)
	if s == nil || id == nil {
		return out(map[string]any{"error": "bad store"})
	}
	if err := s.TouchOpen(C.GoString(id), int64(nowMillis)); err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(map[string]any{"ok": true})
}

//export CULLReport
func CULLReport(h C.int, tone C.int, week C.int) *C.char {
	s := storeAt(h)
	if s == nil {
		return out(map[string]any{"error": "bad store"})
	}
	rep, err := s.Report(int(tone), int(week))
	if err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(rep)
}

//export CULLStats
func CULLStats(h C.int) *C.char {
	s := storeAt(h)
	if s == nil {
		return out(map[string]any{"error": "bad store"})
	}
	st, err := s.Stats()
	if err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(st)
}

//export CULLSetTone
func CULLSetTone(h C.int, tone C.int) *C.char {
	s := storeAt(h)
	if s == nil {
		return out(map[string]any{"error": "bad store"})
	}
	if err := s.SetTone(int(tone)); err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(map[string]any{"ok": true})
}

//export CULLTone
func CULLTone(h C.int) C.int {
	s := storeAt(h)
	if s == nil {
		return 1
	}
	return C.int(s.Tone())
}

//export CULLGetSetting
func CULLGetSetting(h C.int, key *C.char, def *C.char) *C.char {
	s := storeAt(h)
	if s == nil || key == nil {
		return out(map[string]any{"error": "bad store"})
	}
	d := ""
	if def != nil {
		d = C.GoString(def)
	}
	return out(s.GetSetting(C.GoString(key), d))
}

//export CULLSetSetting
func CULLSetSetting(h C.int, key *C.char, value *C.char) *C.char {
	s := storeAt(h)
	if s == nil || key == nil || value == nil {
		return out(map[string]any{"error": "bad store"})
	}
	if err := s.SetSetting(C.GoString(key), C.GoString(value)); err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(map[string]any{"ok": true})
}

//export CULLHasOnboarded
func CULLHasOnboarded(h C.int) C.int {
	s := storeAt(h)
	if s == nil {
		return 0
	}
	if s.HasOnboarded() {
		return 1
	}
	return 0
}

//export CULLMarkOnboarded
func CULLMarkOnboarded(h C.int) *C.char {
	s := storeAt(h)
	if s == nil {
		return out(map[string]any{"error": "bad store"})
	}
	if err := s.MarkOnboarded(); err != nil {
		return out(map[string]any{"error": err.Error()})
	}
	return out(map[string]any{"ok": true})
}

//export CULLIsPro
func CULLIsPro(h C.int) C.int {
	s := storeAt(h)
	if s == nil {
		return 0
	}
	if s.IsPro() {
		return 1
	}
	return 0
}

//export CULLSchemaVersion
func CULLSchemaVersion(h C.int) C.int {
	s := storeAt(h)
	if s == nil {
		return 0
	}
	v, err := s.SchemaVersion()
	if err != nil {
		return 0
	}
	return C.int(v)
}
