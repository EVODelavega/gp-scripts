package main

import (
	"database/sql"
	"flag"
	"fmt"
	_ "github.com/go-sql-driver/mysql"
	"os"
	"strings"
)

type dbConn struct {
    base, target *sql.DB
}

func usage() {
	fmt.Printf("Usage of %s:\n", os.Args[0])
	flag.PrintDefaults()
	fmt.Println("The following flags are required:")
	fmt.Println("username, password, host, base, target")
}

func getArguments() (map[string]string, []string) {
	DSNs := map[string]string{
	    "base": "",
	    "target": "",
	}
	usagePtr := flag.Bool("usage", false, "Display help message")
	userPtr := flag.String("username", "", "DB Username")
	passPtr := flag.String("password", "", "DB password")
	hostPtr := flag.String("host", "tcp(localhost:3306)", "DB host")
	charsetPtr := flag.String("charset", "utf8", "default charset")
	db1Ptr := flag.String("base", "", "Example schema, the one to upgrade to")
	db2Ptr := flag.String("target", "", "Target schema, the one to upgrade")
	flag.Usage = usage
	flag.Parse()
	if *usagePtr {
		usage()
		return DSNs, flag.Args()
	}
	err := false
	if userPtr == nil || *userPtr == "" {
		fmt.Println("username argument is required")
		err = true
	}
	if passPtr == nil || *passPtr == "" {
		fmt.Println("password argument is required")
		err = true
	}
	if db1Ptr == nil || *db1Ptr == "" {
		fmt.Println("base argument is required")
		err = true
	}
	if db2Ptr == nil || *db2Ptr == "" {
		fmt.Println("target argument is required")
		err = true
	}
	if err {
		usage()
		return DSNs, flag.Args()
	}
	DSNs["base"] = fmt.Sprintf("%s:%s@%s/%s?charset=%s", *userPtr, *passPtr, *hostPtr, *db1Ptr, *charsetPtr)
	DSNs["target"] = fmt.Sprintf("%s:%s@%s/%s?charset=%s", *userPtr, *passPtr, *hostPtr, *db2Ptr, *charsetPtr)
	return DSNs, flag.Args()
}

func (con *dbConn) getDbConnections(DSNs map[string]string) error {
	for key, DSN := range DSNs {
		db, err := sql.Open("mysql", DSN)
		if err != nil {
		    if key == "target" {
		        //close connection
		        con.base.Close()
		    }
			return err
		}
		if key == "base" {
		    con.base = db
		} else {
		    con.target = db
		}
	}
	return nil
}

func (con *dbConn) compareCreateStmt(tblName string) (string, error) {
    baseStmt, err := getCreateStmt(con.base, tblName)
    if err != nil {
        return "", err
    }
    targetStmt, err := getCreateStmt(con.target, tblName)
    if err != nil {
        return "", err
    }
    if baseStmt == targetStmt {
        return "", nil
    }
    baseLines := strings.Split(baseStmt, "\n")
    bLen := len(baseLines)
    baseLines = baseLines[1:bLen-2]
    alter := []string{fmt.Sprintf("ALTER TABLE `%s`", tblName)}
    for _, sub := range baseLines {
        if !strings.Contains(targetStmt, sub) {
            alter = append(alter, sub)
        }
    }
    alter = append(alter, ";")
    return strings.Join(alter, "\n"), nil
}

func getCreateStmt(conn *sql.DB, tblName string) (string, error) {
    q := fmt.Sprintf("SHOW CREATE TABLE %s", tblName)
    res, err := conn.Query(q)
    if err != nil {
        return "", err
    }
    defer res.Close()
    res.Next()
    var table, create string;
    err = res.Scan(&table, &create)
    if err != nil {
        return "", err
    }
    return create, nil
}

func main() {
	DSNs, _ := getArguments()
	if DSNs["base"] == "" {
		return
	}
	var conn dbConn;
	err := conn.getDbConnections(DSNs)
	if err != nil {
		panic(err)
	}
	defer conn.base.Close()
	defer conn.target.Close()
	rows, err := conn.base.Query("SHOW TABLES;")
	defer rows.Close()
	if err != nil {
		panic(err)
	}
	hasStmt, err := conn.target.Prepare("SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_NAME = ? AND TABLE_SCHEMA=database();")
	defer hasStmt.Close()
	if err != nil {
		panic(err)
	}
	for rows.Next() {
		var tblName string
		var cnt int
		err = rows.Scan(&tblName)
		if err != nil {
			panic(err)
		}
		exists, err := hasStmt.Query(tblName)
		if err != nil {
			panic(err)
		}
		exists.Next()
		err = exists.Scan(&cnt)
		if err != nil {
			panic(err)
		}
		exists.Close()
		if cnt > 0 {
			fmt.Fprintln(os.Stdout,"-- ", tblName, " exists")
			create, err := conn.compareCreateStmt(tblName)
			if err != nil {
			    panic(err)
			}
			fmt.Println(create)
		} else {
			fmt.Fprintln(os.Stdout, "-- ", tblName, " does not exist")
			create, err := getCreateStmt(conn.base, tblName)
			if err != nil {
			    panic(err)
			}
			fmt.Println(create)
		}
	}
}
