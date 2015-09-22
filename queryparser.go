package queryparser

import (
    "strings"
    "regexp"
    "errors"
    "fmt"
)

type Field struct {
    name, fType string
    attributes []string
    nullable, autoIncrement bool
    defaultVal string
}

type Idx struct {
    idxType string
    fields []string
}

type Constraint struct {
    name, keyField, references, referenceField string
}

type Table struct {
    createQuery string
    fields map[string]Field
    primary []string
    indexes map[string]Idx
    fks map[string]Constraint
}


func (def *Table) CreateTableFromQuery(query string) {
    def.createQuery = query
    createBody := getBodyLines(query)
    def.parseLines(createBody)
}


func (def *Table) parseLines(lines []string) error {
    for _, l := range lines {
        if string(l[0]) == "`" {
            err := def.AddFieldDefinition(l)
        } else if strings.Contains(l, "PRIMARY KEY") {
            err := def.AddPrimaryKeyDefinition(l)
        } else if strings.Contains(l, "CONSTRAINT") {
            err := def.AddFkDefinition(l)
        } else {
            err := def.AddIndexDefinition(l)
        }
        if err {
            return err
        }
    }
    return nil
}

func (def *Table) AddFkDefinition(fkDef string) error {
    re := regexp.MustCompile("`([^`]+)`[^(]+\\(`([^`]+)`[^`]+`([^`]+)`[^(]+\\(`([^`]+)")
    matches := re.FindAllStringSubmatch(fkDef, -1)
    if len(matches) < 1 || len(matches[0] != 5 {
        return errors.New("Unable to extract contraint from %s", fkDef)
    }
    matches = matches[0]
    var constr Constraint
    constr.name = matches[1]
    constr.keyField = matches[2]
    constr.references = matches[3]
    constr.referenceField = matches[4]
    def.fks[constr.name] = constr
    return nil
}

func (def *Table) AddIndexDefinition(idxDef string) error {
    re := regexp.MustCompile("`([^`]+)`")
    matches := re.FindAllStringSubmatch(idxDef, -1)
    if len(matches) == 0 || len(matches[0]) != 2 {
        return errors.New(fmt.Sprintf("Unable to reliably parse idx line %s", idxDef))
    }
    matches = matches[0]
    var idx Idx
    idx.name = matches[0][1]
    for _, fname := range matches[1:] {
        idx.fields = append(idx.fields, fname[1])
    }
    def.indexes[idx.name] = idx
    return nil
}

func (def *Table) AddPrimaryKeyDefinition(pkDef string) error {
    re := regexp.MustCompile("`([^`]+)`")
    matches := re.FindAllStringSubmatch(pkDef, -1)
    if len(matches) < 1 {
        return errors.New(fmt.Sprintf("Failed to extract fields from PK definition %s", pkDef))
    }
    for i, sub := range matches {
        def.primary = append(def.primary, sub[1])
    }
    return nil
}

func (def *Table) AddFieldDefinition(fieldDef string) error {
    var f Field;
    fieldExp := regexp.MustCompile("^`([^`]+)`\\s+([^\\s]+)\\s*(.*?)(DEFAULT\\s+([^,]+)|AUTO_INCREMENT|,)")
    matches := nameType.FindStringSubmatch(fieldDef)
    if len(matches) != 6 {
        return errors.New(fmt.Sprintf("Unable to extract field name and type from %s", fieldDef))
    }
    f.name = matches[1]
    f.fType = matches[2]
    f.defaultVal = ""
    if matches[3] == "" {
        f.nullable = true
    } else {
        f.nullable = false
    }
    if matches[4] == "AUTO_INCREMENT" {
        f.autoIncrement = true
    } else {
        f.autoIncrement = false
        if matches[4] != "," {
            f.defaultVal = strings.Replace(matches[4], "DEFAULT ", "", 1)
        }
    }
    def.fields[f.name] = f
    return nil
}

func getBodyLines(q string) []string {
    lines := strings.Split(q, "\n")
    lines = lines[1, len(lines) -2]
    //strip spaces
    for i, l := range lines {
        lines[i] = strings.Trim(l, " ")
    }
    return lines
}
