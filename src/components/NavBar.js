import React from "react";

export default function NavBar(props) {
  return (
    <nav
      className="navbar navbar-dark fixed-top shadow p-0"
      style={{ backgroundColor: "black", height: "50px", marginTop: "50px" }}
    >
      <a
        className="navbar-brand col-sm-3 col-md-2 mr-0"
        style={{ color: "white" }}
      >
        SeasonPass & Ticket Management
      </a>
      <ul>
        <li>
          <small style={{ color: "white" }}>
            {" "}
            Account Number: {this.props.account}
          </small>
        </li>
      </ul>
    </nav>
  );
}
