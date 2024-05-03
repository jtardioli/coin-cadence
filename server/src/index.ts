import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";

const app = express();

const { PORT } = process.env;

app.use(cors({ origin: "http://localhost:3000", credentials: true }));
app.use(helmet());
app.use(express.json());
app.use(morgan("dev"));

app.get("/", (req, res) => {
  res.send("Application is running");
});
app.get("/api/v1", (req, res) => {
  res.send("Application is running");
});

app.listen(PORT, () => {
  console.log(`🚀 Application listening on PORT::${PORT} 🚀`);
});
