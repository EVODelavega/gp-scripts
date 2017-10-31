// Just replicating internal behaviours of RPC package - making sure json is processed correctly
// decided to keep the script for future reference if I ever end up playing with reflection again
package main

import (
	"encoding/json"
	"fmt"
	"reflect"
)

type OptionalData struct {
	InitiatorId   string `json:"opt_id"`
	InitiatorType string `json:"opt_type"`
}

type Client struct {
	Id    string `json:"id"`
	State string `json:"state"`
}

type Combined struct {
	Client
	Optional OptionalData `json:"optional"`
}

type CombinedPtr struct {
	Client
	Optional *OptionalData `json:"optional,omitempty"`
}

func main() {
	fullS := `{"optional":{"opt_id": "123", "opt_type": "SYS"}, "id": "1", "state": "FOOBAR"}`
	partialS := `{"id": "2", "state": "FOOBAR"}`
	c := Combined{}
	cp := CombinedPtr{}
	set := map[string]interface{}{
		"Combined":    &c,
		"CombinedPtr": &cp,
	}
	fmt.Println("Direct unmarshal on structs - No Optional")
	for k, v := range set {
		fmt.Println(k)
		if err := unmarshal(partialS, v); err != nil {
			fmt.Println(err)
		}
		fmt.Printf("string %s\nUnmarshalled: %#v\n\n", partialS, v)
	}
	fmt.Println("Direct unmarshal on structs - Full string")
	for k, v := range set {
		fmt.Println(k)
		if err := unmarshal(fullS, v); err != nil {
			fmt.Println(err)
		}
		fmt.Printf("string %s\nUnmarshalled: %#v\n\n", fullS, v)
	}
	fmt.Println("-------------------------")
	fmt.Println("Using Reflection now (full string)")
	ref := map[string]reflect.Value{
		"handler":    reflect.ValueOf(handler),
		"ptrHandler": reflect.ValueOf(ptrHandler),
	}
	fmt.Println("Full string - Using reflection")
	for k, v := range ref {
		fmt.Printf("Calling %s\n", k)
		if err := invoke(fullS, v); err != nil {
			fmt.Println(err)
		}
	}
	fmt.Println("No Optional - Using Reflection")
	for k, v := range ref {
		fmt.Printf("Calling %s\n", k)
		if err := invoke(partialS, v); err != nil {
			fmt.Println(err)
		}
	}
}

// don't bother with reflection, assume ptr (because this is a fiddle, and we're calling the func)
func unmarshal(s string, i interface{}) error {
	return json.Unmarshal([]byte(s), i)
}

func invoke(s string, f reflect.Value) error {
	ft := f.Type()
	// only first arg matters, really
	param := ft.In(0)
	if param.Kind() == reflect.Ptr {
		param = param.Elem()
	}
	// get a new interface{} type of this thing
	// params := reflect.New(param).Interface().(interface{})
	// in-line creating a new copy given an instance:
	// toPass := reflect.New(reflect.TypeOf(params).Elem()).Interface()

	// create new instance of whatever type we need
	toPass := reflect.New(param).Interface()
	// technically, we could just do: if err := unmarshal(s, &toPass); err != nil
	if err := json.Unmarshal([]byte(s), &toPass); err != nil {
		return err
	}
	// invoke func through reflection - calls are passed by value
	res := f.Call([]reflect.Value{reflect.ValueOf(toPass)})
	if len(res) == 0 {
		return fmt.Errorf("Unexpected empty return val (%#v)", res)
	}
	fmt.Printf("message %s\n%s\n\n", s, res[0].String())
	return nil
}

func ptrHandler(params *CombinedPtr) string {
	return fmt.Sprintf("unmarshalled: %#v", *params)
}

func handler(params *Combined) string {
	return fmt.Sprintf("unmarshalled: %#v", *params)
}
