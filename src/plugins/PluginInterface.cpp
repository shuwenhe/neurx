#include "PluginInterface.h"

PluginInterface::PluginInterface(QObject *parent)
    : QObject(parent), m_state(Unloaded)
{
}

QString PluginInterface::stateString() const
{
    switch (m_state) {
    case Unloaded: return "Unloaded";
    case Loaded: return "Loaded";
    case Initializing: return "Initializing";
    case Initialized: return "Initialized";
    case Running: return "Running";
    case Paused: return "Paused";
    case Unloading: return "Unloading";
    case Failed: return "Failed";
    case Disabled: return "Disabled";
    default: return "Unknown";
    }
}
