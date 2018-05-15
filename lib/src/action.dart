class Action {
  String type;

  Object payload;

  Action(this.type, [this.payload]);

  String toString() {
    return "Action(${this.type}, ${this.payload})";
  }
}
