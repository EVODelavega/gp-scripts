package main

import (
	"database/sql"
	"flag"
	"fmt"
	_ "github.com/go-sql-driver/mysql"
	"os"
)

func usage() {
	fmt.Printf("Usage of %s:\n", os.Args[0])
	flag.PrintDefaults()
	fmt.Println("The following flags are required:")
	fmt.Println("username, password, host, base, target")
}

func getArguments() ([]string, []string) {
	var DSNs []string
	DSNs = make([]string, 2)
	DSNs[0] = ""
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
	DSNs[0] = fmt.Sprintf("%s:%s@%s/%s?charset=%s", *userPtr, *passPtr, *hostPtr, *db1Ptr, *charsetPtr)
	DSNs[1] = fmt.Sprintf("%s:%s@%s/%s?charset=%s", *userPtr, *passPtr, *hostPtr, *db2Ptr, *charsetPtr)
	return DSNs, flag.Args()
}

func getDbConnections(DSNs []string) ([]*sql.DB, error) {
	dbs := make([]*sql.DB, len(DSNs))
	for i, DSN := range DSNs {
		db, err := sql.Open("mysql", DSN)
		if err != nil {
			for j := 0; j < i; j++ {
				dbs[j].Close()
			}
			return dbs, err
		}
		dbs[i] = db
	}
	return dbs, nil
}

func getCreateStmt(conn *sql.DB, tblName string) error {
    q := fmt.Sprintf("SHOW CREATE TABLE %s", tblName)
    res, err := conn.Query(q)
    if err != nil {
        return err
    }
    defer res.Close()
    res.Next()
    var table, create string;
    err = res.Scan(&table, &create)
    if err != nil {
        return err
    }
    fmt.Println(create)
    return nil
}

func main() {
	DSNs, _ := getArguments()
	if DSNs[0] == "" {
		return
	}
	dbs, err := getDbConnections(DSNs)
	if err != nil {
		panic(err)
	}
	for i := 0; i < len(dbs); i++ {
		defer dbs[i].Close()
	}
	db := dbs[0]
	target := dbs[1]
	rows, err := db.Query("SHOW TABLES;")
	defer rows.Close()
	if err != nil {
		panic(err)
	}
	hasStmt, err := target.Prepare("SELECT COUNT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_NAME = ? AND TABLE_SCHEMA=database();")
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
		} else {
			fmt.Fprintln(os.Stdout, "-- ", tblName, " does not exist")
			err = getCreateStmt(db, tblName)
			if err != nil {
			    panic(err)
			}
		}
	}
}
