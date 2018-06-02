class Action {
  String type;

  Object payload;

  Action(this.type, [this.payload]);

  String toString() {
    return "Action(${this.type}, ${this.payload})";
  }

  bool operator ==(other) {
    return (other is Action &&
        other.type == this.type &&
        other.payload == this.payload);
  }
}
