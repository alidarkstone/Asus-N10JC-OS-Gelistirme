-- N10JC (Realtek ALC662): always use the analog output (speakers / headphone jack),
-- never the codec's HDMI/digital profile.
table.insert(alsa_monitor.rules, {
  matches = { { { "device.name", "matches", "alsa_card.pci-0000_00_1b.0" } } },
  apply_properties = { ["device.profile"] = "output:analog-stereo+input:analog-stereo" },
})
