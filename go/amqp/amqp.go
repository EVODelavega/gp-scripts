/**
 * Quick and dirty test performance of go + AMQP
 * In the actual test, I used RabbitMQ, producing 1500 messages
 * On average took about 40ms, never more than 55ms
 *
 * Consuming 1500 messages (and printing them) took on average
 * 223ms. Unmarshaling them into the Message type brought the average
 * down to about 450ms (with fmt.Printf("%T %+v")
 * Wanted to see how fast producing/consuming AMQP messages w
 */ // produce
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"time"

	"github.com/streadway/amqp"
)

const amqpserver string = "amqp://guest:guest@10.20.30.40:5672"

type RunMode struct {
	Mode      *string
	Queue     *string
	Body      *string
	Extra     *string
	Count     *int
	done      chan error
	consCount int
}

type Message struct {
	Id    int64  `json:"individual_id"`
	Name  string `json:"individual_name"`
	Extra string `json:"extra_info"`
}

func failOnError(err error, msg string) {
	if err != nil {
		log.Fatalf("%s: %s", msg, err)
		panic(fmt.Sprintf("%s: %s", msg, err))
	}
}

func (m *Message) GetBytes() []byte {
	jBytes, err := json.Marshal(m)
	if err != nil {
		failOnError(err, "Failed to marshal Message struct")
	}
	return jBytes
}

func (m *Message) ParseInto(str []byte) (*Message, error) {
	err := json.Unmarshal(str, m)
	if err != nil {
		return m, err
	}
	return m, nil
}

func produceMessage(ch *amqp.Channel, q *amqp.Queue, message []byte) error {
	return ch.Publish(
		"",     // exchange
		q.Name, // routing key
		false,  // mandatory
		false,  // immediate
		amqp.Publishing{
			ContentType: "text/plain",
			Body:        message,
		})
}

func setFlags() *RunMode {
	r := &RunMode{}
	r.Mode = flag.String("mode", "produce", "produce or consume, decide which mode to run in")
	r.Queue = flag.String("queue", "testQ", "queque name to use")
	if *r.Mode == "produce" {
		r.Body = flag.String("message", "default msg", "Specify the body of the message to produce")
		r.Extra = flag.String("extra", "", "Add extra content to message")
	}
	r.Count = flag.Int("count", 1, "Specify how many messages to produce/consume")
	flag.Parse()
	return r
}

func main() {
	mode := setFlags()
	conn, err := amqp.Dial(amqpserver)
	failOnError(err, "Failed to connect to RabbitMQ")
	defer conn.Close()

	ch, err := conn.Channel()
	failOnError(err, "Failed to open a channel")
	defer ch.Close()

	if *mode.Mode != "produce" {
		//we're trying to consume
		err = ch.ExchangeDeclare(
			"exchange-name",
			"direct", // type
			false,
			true,
			false,
			false,
			nil,
		)
		failOnError(err, "Failed to declare a queue")

	}

	//always open queue
	q, err := ch.QueueDeclare(
		*mode.Queue,
		false,
		false,
		false,
		false,
		nil,
	)
	failOnError(err, "Failed to declare a queue")

	if *mode.Mode == "produce" {
		start := time.Now()
		baseMsg := Message{
			Name:  *mode.Body,
			Extra: *mode.Extra,
		}
		for i := 0; i < *mode.Count; i++ {
			baseMsg.Id = int64(i)
			err = produceMessage(
				ch,
				&q,
				baseMsg.GetBytes(),
			)

			failOnError(err, "Failed to publish a message")
		}
		elapsed := time.Since(start)
		fmt.Printf(
			"Producing %d messages took %s\n",
			*mode.Count,
			elapsed,
		)
		return
	} //tag simple-consumer
	key := "ckey"
	fmt.Printf(
		"Queue %q has %d messages, %d consumers, binding to Exchange (key %q)",
		q.Name,
		q.Messages,
		q.Consumers,
		key,
	)
	ch.QueueBind(
		q.Name,
		key,
		"exchange-name",
		false,
		nil,
	)
	start := time.Now()
	deliveries, err := ch.Consume(
		q.Name,
		"simple-consumer",
		false,
		false,
		false,
		false,
		nil,
	)
	failOnError(err, "Failed to start consuming")

	mode.done = make(chan error)
	go handle(deliveries, mode)
	//blocking wait for done
	err = <-mode.done
	failOnError(err, "consuming failed at some point")
	elapsed := time.Since(start)
	fmt.Printf(
		"Consuming %d messages took %s\n",
		*mode.Count,
		elapsed,
	)
}

func handle(deliveries <-chan amqp.Delivery, mode *RunMode) {
	m := Message{}
	for d := range deliveries {
		mode.consCount += 1
		fmt.Printf(
			"got %dB delivery: [%v] %q\n",
			len(d.Body),
			d.DeliveryTag,
			d.Body,
		)
		d.Ack(false)
		if _, err := m.ParseInto(d.Body); err != nil {
			fmt.Printf("Failed to unmarshal message: %s\n", err.Error())
		} else {
			fmt.Printf("Unmarshalled message: %T -> %+v\n", m, m)
		}
		if mode.consCount >= *mode.Count {
			break
		}
	}
	fmt.Printf(
		"Finished consuming %d messages",
		mode.consCount,
	)
	mode.done <- nil
}
