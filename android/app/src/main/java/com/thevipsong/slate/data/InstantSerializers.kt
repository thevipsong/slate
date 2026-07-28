package com.thevipsong.slate.data

import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant

object InstantIsoSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("SlateInstant", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Instant) {
        encoder.encodeString(value.toString())
    }

    override fun deserialize(decoder: Decoder): Instant =
        Instant.parse(decoder.decodeString())
}

@OptIn(ExperimentalSerializationApi::class)
object NullableInstantIsoSerializer : KSerializer<Instant?> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("SlateNullableInstant", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Instant?) {
        if (value == null) encoder.encodeNull() else encoder.encodeString(value.toString())
    }

    override fun deserialize(decoder: Decoder): Instant? =
        if (decoder.decodeNotNullMark()) Instant.parse(decoder.decodeString()) else {
            decoder.decodeNull()
            null
        }
}
