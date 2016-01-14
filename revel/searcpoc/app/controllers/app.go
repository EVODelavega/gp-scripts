package controllers

import (
	"encoding/json"
	"github.com/revel/revel"
	"io/ioutil"
)

type App struct {
	*revel.Controller
}

type QueryString struct {
	Q string `json:"q"`
}

func (c App) Index() revel.Result {
	var foo string
	foo = "bar"
	return c.Render(foo)
}

func (c App) Search() revel.Result {
	var query QueryString
	raw, err := ioutil.ReadAll(c.Request.Body)
	if err != nil {
		panic("Error reading reques")
	}
	err = json.Unmarshal(raw, &query)
	return c.RenderJson(query)
}
