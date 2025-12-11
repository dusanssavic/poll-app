package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// Vote holds the schema definition for the Vote entity.
type Vote struct {
	ent.Schema
}

// Fields of the Vote.
func (Vote) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.UUID("user_id", uuid.UUID{}),
		field.UUID("poll_id", uuid.UUID{}),
		field.String("option").NotEmpty(),
		field.Time("created_at").Default(time.Now),
	}
}

// Edges of the Vote.
func (Vote) Edges() []ent.Edge {
	return []ent.Edge{
		edge.To("user", User.Type).
			Field("user_id").
			Required().
			Unique(),
		edge.To("poll", Poll.Type).
			Field("poll_id").
			Required().
			Unique(),
	}
}

// Indexes of the Vote.
func (Vote) Indexes() []ent.Index {
	return []ent.Index{
		// Ensure one vote per user per poll
		index.Fields("user_id", "poll_id").Unique(),
	}
}
