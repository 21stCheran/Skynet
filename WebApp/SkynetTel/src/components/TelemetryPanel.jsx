import React from "react";
import {
  Card,
  CardContent,
  Typography,
  Box,
  List,
  ListItem,
  ListItemText,
  Button,
  Paper,
  Chip,
  Divider,
} from "@mui/material";
import { Message, Clear, Download, Timeline } from "@mui/icons-material";

const TelemetryPanel = ({ receivedMessages, onClearMessages }) => {
  const exportLogs = () => {
    const logData = receivedMessages
      .map((msg) => `${msg.timestamp}: ${msg.message}`)
      .join("\n");

    const blob = new Blob([logData], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `skynet-telemetry-${new Date()
      .toISOString()
      .slice(0, 19)}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const getMessageType = (message) => {
    if (message.includes("Sent:")) return "sent";
    if (message.includes("Received:")) return "received";
    if (message.includes("Response:")) return "response";
    if (message.includes("Connected") || message.includes("Connection"))
      return "connection";
    if (message.includes("Error") || message.includes("Failed")) return "error";
    return "info";
  };

  const getMessageColor = (type) => {
    switch (type) {
      case "sent":
        return "primary";
      case "received":
        return "success";
      case "response":
        return "info";
      case "connection":
        return "warning";
      case "error":
        return "error";
      default:
        return "default";
    }
  };

  const MessageItem = ({ msg }) => {
    const type = getMessageType(msg.message);
    const color = getMessageColor(type);

    return (
      <ListItem
        divider
        sx={{
          bgcolor:
            type === "error"
              ? "error.light"
              : type === "sent"
              ? "primary.light"
              : type === "received"
              ? "success.light"
              : "transparent",
          opacity: type === "error" ? 1 : 0.9,
          "&:hover": { bgcolor: "action.hover" },
        }}
      >
        <ListItemText
          primary={
            <Box display="flex" alignItems="center" gap={1}>
              <Chip
                label={type.toUpperCase()}
                size="small"
                color={color}
                variant="outlined"
              />
              <Typography variant="body2" component="span">
                {msg.message}
              </Typography>
            </Box>
          }
          secondary={msg.timestamp}
        />
      </ListItem>
    );
  };

  return (
    <Card elevation={3}>
      <CardContent>
        <Box
          display="flex"
          alignItems="center"
          justifyContent="space-between"
          mb={2}
        >
          <Box display="flex" alignItems="center" gap={1}>
            <Timeline color="action" />
            <Typography variant="h6" component="h2">
              Communication Log
            </Typography>
            <Chip
              label={`${receivedMessages.length} messages`}
              size="small"
              color="info"
              variant="outlined"
            />
          </Box>

          <Box display="flex" gap={1}>
            <Button
              variant="outlined"
              size="small"
              onClick={exportLogs}
              startIcon={<Download />}
              disabled={receivedMessages.length === 0}
            >
              Export
            </Button>
            <Button
              variant="outlined"
              size="small"
              color="error"
              onClick={onClearMessages}
              startIcon={<Clear />}
              disabled={receivedMessages.length === 0}
            >
              Clear
            </Button>
          </Box>
        </Box>

        <Paper
          elevation={1}
          sx={{
            maxHeight: 400,
            overflow: "auto",
            border: "1px solid",
            borderColor: "divider",
          }}
        >
          {receivedMessages.length === 0 ? (
            <Box
              display="flex"
              flexDirection="column"
              alignItems="center"
              justifyContent="center"
              p={4}
              color="text.secondary"
            >
              <Message sx={{ fontSize: 48, mb: 2, opacity: 0.5 }} />
              <Typography variant="h6" gutterBottom>
                No messages yet
              </Typography>
              <Typography variant="body2" textAlign="center">
                Connect to your ESP32 and send commands to see telemetry data
                here.
              </Typography>
            </Box>
          ) : (
            <List dense>
              {receivedMessages.map((msg) => (
                <MessageItem key={msg.id} msg={msg} />
              ))}
            </List>
          )}
        </Paper>

        {receivedMessages.length > 0 && (
          <Box mt={2}>
            <Typography variant="caption" color="text.secondary">
              Messages are automatically limited to the most recent 100 entries.
              Use Export to save all messages to a file.
            </Typography>
          </Box>
        )}
      </CardContent>
    </Card>
  );
};

export default TelemetryPanel;
